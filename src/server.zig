const std = @import("std");
const core = @import("core");
const server = core.server;
const runner = core.runner;
const config_loader = @import("config_loader.zig");

const port: u16 = 8080;

pub const LoadedApp = struct {
    cwasm_bytes: []u8,
    config: core.tsubu_config.Config,

    pub fn deinit(self: LoadedApp, gpa: std.mem.Allocator) void {
        gpa.free(self.cwasm_bytes);
        self.config.deinit(gpa);
    }
};

/// Resolves every request to the same, fixed wasm component and config
/// files on disk, recompiling the component on every request (there's no
/// on-disk cwasm cache here, unlike `tsubu_cloud_server`: local runs are
/// short-lived and the component may be being actively edited/rebuilt).
/// Used for local development via `tsubu_cloud_local`.
fn resolve(gpa: std.mem.Allocator, io: std.Io, wasm_path: []const u8, config_path: []const u8) !LoadedApp {
    const wasm_bytes = try std.Io.Dir.cwd().readFileAlloc(io, wasm_path, gpa, .unlimited);
    defer gpa.free(wasm_bytes);

    const cwasm_bytes = try runner.compileToCwasm(gpa, wasm_bytes);
    errdefer gpa.free(cwasm_bytes);

    const config = try config_loader.load(gpa, io, config_path);

    return .{ .cwasm_bytes = cwasm_bytes, .config = config };
}

pub fn serve(gpa: std.mem.Allocator, io: std.Io, wasm_path: []const u8, config_path: []const u8) !void {
    var address = std.Io.net.IpAddress.parse("0.0.0.0", port) catch unreachable;
    var tcp_server = try address.listen(io, .{ .reuse_address = true });
    defer tcp_server.deinit(io);

    std.debug.print("listening on http://0.0.0.0:{d}/\n", .{port});

    // Each connection is spawned into this group instead of being handled
    // inline, since a connection's keep-alive loop blocks waiting for
    // further requests; handling connections synchronously here would let
    // one idle client starve every other connection from ever being
    // accepted.
    var group: std.Io.Group = .init;
    defer group.cancel(io);

    while (true) {
        const stream = tcp_server.accept(io) catch |err| {
            std.debug.print("failed to accept connection: {t}\n", .{err});
            continue;
        };
        group.async(io, serveConnection, .{ gpa, io, wasm_path, config_path, stream });
    }
}

fn serveConnection(gpa: std.mem.Allocator, io: std.Io, wasm_path: []const u8, config_path: []const u8, stream: std.Io.net.Stream) std.Io.Cancelable!void {
    defer stream.close(io);
    handleConnection(gpa, io, wasm_path, config_path, stream) catch |err| {
        std.debug.print("failed to serve connection: {t}\n", .{err});
    };
}

fn handleConnection(gpa: std.mem.Allocator, io: std.Io, wasm_path: []const u8, config_path: []const u8, stream: std.Io.net.Stream) !void {
    var recv_buffer: [8192]u8 = undefined;
    var send_buffer: [8192]u8 = undefined;
    var connection_reader = stream.reader(io, &recv_buffer);
    var connection_writer = stream.writer(io, &send_buffer);
    var http_server = std.http.Server.init(&connection_reader.interface, &connection_writer.interface);

    while (true) {
        var request = http_server.receiveHead() catch |err| switch (err) {
            error.HttpConnectionClosing => return,
            else => return err,
        };
        try handleRequest(gpa, io, wasm_path, config_path, &request);
    }
}

fn handleRequest(gpa: std.mem.Allocator, io: std.Io, wasm_path: []const u8, config_path: []const u8, request: *std.http.Server.Request) !void {
    const method_str = @tagName(request.head.method);

    // `readerExpectContinue` invalidates the string fields of `request.head`
    // (including `target`), so the URL must be captured beforehand.
    const url = request.head.target;

    var header_list: std.ArrayList([2][]const u8) = .empty;
    defer header_list.deinit(gpa);
    var it = request.iterateHeaders();
    while (it.next()) |h| {
        try header_list.append(gpa, .{ h.name, h.value });
    }

    var body_buffer: [8192]u8 = undefined;
    const body_reader = request.readerExpectContinue(&body_buffer) catch |err| {
        std.debug.print("failed to read request body: {t}\n", .{err});
        return;
    };
    const body = try body_reader.allocRemaining(gpa, .unlimited);
    defer gpa.free(body);

    const req: runner.Request = .{
        .url = url,
        .method = method_str,
        .headers = header_list.items,
        .body = body,
    };

    const app = resolve(gpa, io, wasm_path, config_path) catch |err| {
        std.debug.print("failed to load app: {t}\n", .{err});
        try request.respond("internal server error\n", .{ .status = .internal_server_error });
        return;
    };
    defer app.deinit(gpa);

    const log_messages = try server.runAndRespond(gpa, io, app.cwasm_bytes, app.config, req, request);
    defer {
        for (log_messages) |m| gpa.free(m);
        gpa.free(log_messages);
    }
}

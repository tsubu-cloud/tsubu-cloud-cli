const std = @import("std");
const core = @import("core");
const config_loader = @import("../config_loader.zig");
const templates = @import("templates.zig");

const fetcher_package_prefix_wit = templates.fetcher_package_prefix_wit;
const logger_package_wit = templates.logger_package_wit;
const handler_package_wit = templates.handler_package_wit;
const postgres_package_prefix_wit = templates.postgres_package_prefix_wit;

fn writeDepPackage(io: std.Io, out_dir: []const u8, pkg_name: []const u8, contents: []const u8) !void {
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const dir_path = try std.fmt.bufPrint(&buf, "{s}/deps/{s}", .{ out_dir, pkg_name });
    try std.Io.Dir.cwd().createDirPath(io, dir_path);

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const file_path = try std.fmt.bufPrint(&path_buf, "{s}/package.wit", .{dir_path});
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = file_path, .data = contents });
}

/// Generates `wit/deps/*/package.wit` for the host interfaces (`fetcher`,
/// `postgres`, `logger`, `variables`) and the shared `handler` types that
/// `tsubu.json` at `config_path` references, and (only if it doesn't
/// already exist) a `wit/guest.wit` template importing them.
///
/// `logger` and `handler` are always generated: unlike `fetch`/`postgres`/
/// `variables` they have no corresponding `tsubu.json` array, so their use
/// can't be detected from the config alone, and they're cheap/harmless to
/// always make available. `fetch`/`postgres`/`variables` each expose one
/// function per alias listed in the corresponding `tsubu.json` array (the
/// function name equals the alias), mirroring how `runner.zig` wires up
/// `hostFetch`/`hostQuery`/`hostGetVariable` via `defineFunc(t.alias, ...)`.
pub fn generate(gpa: std.mem.Allocator, io: std.Io, config_path: []const u8, out_dir: []const u8) !void {
    const config = try config_loader.load(gpa, io, config_path);
    defer config.deinit(gpa);

    const use_fetcher = config.fetch_targets.len > 0;
    const use_postgres = config.postgres_targets.len > 0;
    const use_variables = config.variable_targets.len > 0;

    try writeDepPackage(io, out_dir, "logger", logger_package_wit);
    try writeDepPackage(io, out_dir, "handler", handler_package_wit);
    if (use_fetcher) {
        var fetcher_wit: std.ArrayList(u8) = .empty;
        defer fetcher_wit.deinit(gpa);
        try fetcher_wit.appendSlice(gpa, fetcher_package_prefix_wit);
        for (config.fetch_targets) |t| {
            try fetcher_wit.print(gpa, "    {s}: func(request: request) -> response;\n", .{t.alias});
        }
        try fetcher_wit.appendSlice(gpa, "}\n");
        try writeDepPackage(io, out_dir, "fetcher", fetcher_wit.items);
    }
    if (use_postgres) {
        var postgres_wit: std.ArrayList(u8) = .empty;
        defer postgres_wit.deinit(gpa);
        try postgres_wit.appendSlice(gpa, postgres_package_prefix_wit);
        for (config.postgres_targets) |t| {
            try postgres_wit.print(gpa, "    {s}: func(statement: string, params: list<parameter-value>) -> result<row-set, error>;\n", .{t.alias});
        }
        try postgres_wit.appendSlice(gpa, "}\n");
        try writeDepPackage(io, out_dir, "postgres", postgres_wit.items);
    }
    if (use_variables) {
        var variables_wit: std.ArrayList(u8) = .empty;
        defer variables_wit.deinit(gpa);
        try variables_wit.appendSlice(gpa,
            \\package tsubu-cloud:variables;
            \\
            \\interface variables {
            \\
        );
        for (config.variable_targets) |t| {
            try variables_wit.print(gpa, "    {s}: func() -> string;\n", .{t.alias});
        }
        try variables_wit.appendSlice(gpa, "}\n");
        try writeDepPackage(io, out_dir, "variables", variables_wit.items);
    }

    var guest_path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const guest_path = try std.fmt.bufPrint(&guest_path_buf, "{s}/guest.wit", .{out_dir});

    const guest_exists = blk: {
        std.Io.Dir.cwd().access(io, guest_path, .{}) catch break :blk false;
        break :blk true;
    };
    if (guest_exists) {
        std.debug.print(
            "note: {s} already exists, leaving it untouched. Make sure it imports:\n" ++
                "  import tsubu-cloud:logger/logger;\n",
            .{guest_path},
        );
        if (use_fetcher) std.debug.print("  import tsubu-cloud:fetcher/fetcher;\n", .{});
        if (use_postgres) std.debug.print("  import tsubu-cloud:postgres/postgres;\n", .{});
        if (use_variables) std.debug.print("  import tsubu-cloud:variables/variables;\n", .{});
        return;
    }

    var guest_wit: std.ArrayList(u8) = .empty;
    defer guest_wit.deinit(gpa);

    try guest_wit.appendSlice(gpa,
        \\package guest:handler;
        \\
        \\world guest {
        \\    use tsubu-cloud:handler/types.{request, response};
        \\
        \\    import tsubu-cloud:logger/logger;
        \\
    );
    if (use_fetcher) try guest_wit.appendSlice(gpa, "    import tsubu-cloud:fetcher/fetcher;\n");
    if (use_postgres) try guest_wit.appendSlice(gpa, "    import tsubu-cloud:postgres/postgres;\n");
    if (use_variables) try guest_wit.appendSlice(gpa, "    import tsubu-cloud:variables/variables;\n");
    try guest_wit.appendSlice(gpa,
        \\
        \\    export handler: func(request: request) -> response;
        \\}
        \\
    );

    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = guest_path, .data = guest_wit.items });
}

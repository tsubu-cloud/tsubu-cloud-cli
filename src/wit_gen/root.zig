const std = @import("std");
const core = @import("core");
const config_loader = @import("../config_loader.zig");

/// Static prefix of the `tsubu-cloud:fetcher` package: the shared
/// `interface types` block plus the opening of `interface fetcher`. Per-alias
/// `fetch: func(...)` declarations are appended by `generate`.
const fetcher_package_prefix_wit =
    \\package tsubu-cloud:fetcher;
    \\
    \\interface types {
    \\    record request {
    \\        method: string,
    \\        headers: list<tuple<string, string>>,
    \\        body: string,
    \\    }
    \\
    \\    record response {
    \\        status: u16,
    \\        headers: list<tuple<string, string>>,
    \\        body: string,
    \\    }
    \\}
    \\
    \\interface fetcher {
    \\    use types.{request, response};
    \\
;

const logger_package_wit =
    \\package tsubu-cloud:logger;
    \\
    \\interface logger {
    \\    log: func(message: string);
    \\}
    \\
;

/// Shared `interface types` block for the guest `handler` world: the HTTP
/// request/response records the exported `handler` function operates on.
/// Always generated under `wit/deps/handler/package.wit` so guest
/// scaffolding can `import tsubu-cloud:handler/types` and reuse the same
/// type definitions instead of redeclaring them inline.
const handler_package_wit =
    \\package tsubu-cloud:handler;
    \\
    \\interface types {
    \\    record request {
    \\        url: string,
    \\        method: string,
    \\        headers: list<tuple<string, string>>,
    \\        body: string,
    \\    }
    \\
    \\    record response {
    \\        status: u16,
    \\        headers: list<tuple<string, string>>,
    \\        body: string,
    \\    }
    \\}
    \\
;
/// Static prefix of the `tsubu-cloud:postgres` package: the shared
/// `interface types` block plus the opening of `interface postgres`. Per-alias
/// `query: func(...)` declarations are appended by `generate`.
const postgres_package_prefix_wit =
    \\package tsubu-cloud:postgres;
    \\
    \\interface types {
    \\  /// Errors related to interacting with a database.
    \\  variant error {
    \\      connection-failed(string),
    \\      bad-parameter(string),
    \\      query-failed(query-error),
    \\      value-conversion-failed(string),
    \\      other(string)
    \\  }
    \\
    \\  variant query-error {
    \\      /// An error occurred but we do not have structured info for it
    \\      text(string),
    \\      /// Postgres returned a structured database error
    \\      db-error(db-error),
    \\  }
    \\
    \\  record db-error {
    \\      /// Stringised version of the error. This is primarily to facilitate migration of older code.
    \\      as-text: string,
    \\      severity: string,
    \\      code: string,
    \\      message: string,
    \\      detail: option<string>,
    \\      /// Any error information provided by Postgres and not captured above.
    \\      extras: list<tuple<string, string>>,
    \\  }
    \\
    \\  /// Data types for a database column
    \\  variant db-data-type {
    \\      boolean,
    \\      int8,
    \\      int16,
    \\      int32,
    \\      int64,
    \\      floating32,
    \\      floating64,
    \\      str,
    \\      binary,
    \\      date,
    \\      time,
    \\      datetime,
    \\      timestamp,
    \\      uuid,
    \\      jsonb,
    \\      decimal,
    \\      range-int32,
    \\      range-int64,
    \\      range-decimal,
    \\      array-int32,
    \\      array-int64,
    \\      array-decimal,
    \\      array-str,
    \\      interval,
    \\      other(string),
    \\  }
    \\
    \\  /// Database values
    \\  variant db-value {
    \\      boolean(bool),
    \\      int8(s8),
    \\      int16(s16),
    \\      int32(s32),
    \\      int64(s64),
    \\      floating32(f32),
    \\      floating64(f64),
    \\      str(string),
    \\      binary(list<u8>),
    \\      date(tuple<s32, u8, u8>), // (year, month, day)
    \\      time(tuple<u8, u8, u8, u32>), // (hour, minute, second, nanosecond)
    \\      /// Date-time types are always treated as UTC (without timezone info).
    \\      /// The instant is represented as a (year, month, day, hour, minute, second, nanosecond) tuple.
    \\      datetime(tuple<s32, u8, u8, u8, u8, u8, u32>),
    \\      /// Unix timestamp (seconds since epoch)
    \\      timestamp(s64),
    \\      uuid(string),
    \\      jsonb(list<u8>),
    \\      decimal(string), // I admit defeat. Base 10
    \\      range-int32(tuple<option<tuple<s32, range-bound-kind>>, option<tuple<s32, range-bound-kind>>>),
    \\      range-int64(tuple<option<tuple<s64, range-bound-kind>>, option<tuple<s64, range-bound-kind>>>),
    \\      range-decimal(tuple<option<tuple<string, range-bound-kind>>, option<tuple<string, range-bound-kind>>>),
    \\      array-int32(list<option<s32>>),
    \\      array-int64(list<option<s64>>),
    \\      array-decimal(list<option<string>>),
    \\      array-str(list<option<string>>),
    \\      interval(interval),
    \\      db-null,
    \\      unsupported(list<u8>),
    \\  }
    \\
    \\  /// Values used in parameterized queries
    \\  variant parameter-value {
    \\      boolean(bool),
    \\      int8(s8),
    \\      int16(s16),
    \\      int32(s32),
    \\      int64(s64),
    \\      floating32(f32),
    \\      floating64(f64),
    \\      str(string),
    \\      binary(list<u8>),
    \\      date(tuple<s32, u8, u8>), // (year, month, day)
    \\      time(tuple<u8, u8, u8, u32>), // (hour, minute, second, nanosecond)
    \\      /// Date-time types are always treated as UTC (without timezone info).
    \\      /// The instant is represented as a (year, month, day, hour, minute, second, nanosecond) tuple.
    \\      datetime(tuple<s32, u8, u8, u8, u8, u8, u32>),
    \\      /// Unix timestamp (seconds since epoch)
    \\      timestamp(s64),
    \\      uuid(string),
    \\      jsonb(list<u8>),
    \\      decimal(string), // base 10
    \\      range-int32(tuple<option<tuple<s32, range-bound-kind>>, option<tuple<s32, range-bound-kind>>>),
    \\      range-int64(tuple<option<tuple<s64, range-bound-kind>>, option<tuple<s64, range-bound-kind>>>),
    \\      range-decimal(tuple<option<tuple<string, range-bound-kind>>, option<tuple<string, range-bound-kind>>>),
    \\      array-int32(list<option<s32>>),
    \\      array-int64(list<option<s64>>),
    \\      array-decimal(list<option<string>>),
    \\      array-str(list<option<string>>),
    \\      interval(interval),
    \\      db-null,
    \\  }
    \\
    \\  record interval {
    \\    micros: s64,
    \\    days: s32,
    \\    months: s32,
    \\  }
    \\
    \\  /// A database column
    \\  record column {
    \\      name: string,
    \\      data-type: db-data-type,
    \\  }
    \\
    \\  /// A database row
    \\  type row = list<db-value>;
    \\
    \\  /// A set of database rows
    \\  record row-set {
    \\      columns: list<column>,
    \\      rows: list<row>,
    \\  }
    \\
    \\  /// For range types, indicates if each bound is inclusive or exclusive
    \\  enum range-bound-kind {
    \\    inclusive,
    \\    exclusive,
    \\  }
    \\}
    \\
    \\interface postgres {
    \\  use types.{parameter-value, row-set, error};
    \\
;

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

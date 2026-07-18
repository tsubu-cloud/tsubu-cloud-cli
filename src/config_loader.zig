const std = @import("std");
const core = @import("core");
const tsubu_config = core.tsubu_config;
const Config = tsubu_config.Config;
const FetchTarget = tsubu_config.FetchTarget;
const PostgresTarget = tsubu_config.PostgresTarget;
const VariableTarget = tsubu_config.VariableTarget;

const RawFetchTarget = struct {
    ALIAS: []const u8,
    TARGET: []const u8,
};

const RawPostgresTarget = struct {
    ALIAS: []const u8,
    DATABASE_URL: []const u8,
};

const RawVariableTarget = struct {
    ALIAS: []const u8,
    VALUE: []const u8,
};

const RawConfig = struct {
    fetch: []const RawFetchTarget,
    postgres: []const RawPostgresTarget,
    variables: []const RawVariableTarget,
};

/// Loads the JSON config file at `path`, if present. Returns an empty
/// `Config` if the file doesn't exist.
///
/// Expects a top-level object with `fetch`, `postgres` and `variables`
/// arrays, each holding objects with string `ALIAS`/`TARGET` (fetch),
/// `ALIAS`/`DATABASE_URL` (postgres) or `ALIAS`/`VALUE` (variables) keys.
pub fn load(gpa: std.mem.Allocator, io: std.Io, path: []const u8) !Config {
    const contents = std.Io.Dir.cwd().readFileAlloc(io, path, gpa, .unlimited) catch |err| switch (err) {
        error.FileNotFound => return .{ .fetch_targets = &.{}, .postgres_targets = &.{}, .variable_targets = &.{} },
        else => return err,
    };
    defer gpa.free(contents);

    const parsed = try std.json.parseFromSlice(RawConfig, gpa, contents, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    var fetch_targets: std.ArrayList(FetchTarget) = .empty;
    errdefer {
        for (fetch_targets.items) |t| {
            gpa.free(t.alias);
            gpa.free(t.target);
        }
        fetch_targets.deinit(gpa);
    }
    try fetch_targets.ensureTotalCapacityPrecise(gpa, parsed.value.fetch.len);
    for (parsed.value.fetch) |raw| {
        fetch_targets.appendAssumeCapacity(.{
            .alias = try gpa.dupe(u8, raw.ALIAS),
            .target = try gpa.dupe(u8, raw.TARGET),
        });
    }

    var postgres_targets: std.ArrayList(PostgresTarget) = .empty;
    errdefer {
        for (postgres_targets.items) |t| {
            gpa.free(t.alias);
            gpa.free(t.database_url);
        }
        postgres_targets.deinit(gpa);
    }
    try postgres_targets.ensureTotalCapacityPrecise(gpa, parsed.value.postgres.len);
    for (parsed.value.postgres) |raw| {
        postgres_targets.appendAssumeCapacity(.{
            .alias = try gpa.dupe(u8, raw.ALIAS),
            .database_url = try gpa.dupe(u8, raw.DATABASE_URL),
        });
    }

    var variable_targets: std.ArrayList(VariableTarget) = .empty;
    errdefer {
        for (variable_targets.items) |t| {
            gpa.free(t.alias);
            gpa.free(t.value);
        }
        variable_targets.deinit(gpa);
    }
    try variable_targets.ensureTotalCapacityPrecise(gpa, parsed.value.variables.len);
    for (parsed.value.variables) |raw| {
        variable_targets.appendAssumeCapacity(.{
            .alias = try gpa.dupe(u8, raw.ALIAS),
            .value = try gpa.dupe(u8, raw.VALUE),
        });
    }

    return .{
        .fetch_targets = try fetch_targets.toOwnedSlice(gpa),
        .postgres_targets = try postgres_targets.toOwnedSlice(gpa),
        .variable_targets = try variable_targets.toOwnedSlice(gpa),
    };
}

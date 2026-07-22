//! Static WIT package templates used by `root.zig`'s `generate`.

/// Static prefix of the `tsubu-cloud:fetcher` package: the shared
/// `interface types` block plus the opening of `interface fetcher`. Per-alias
/// `fetch: func(...)` declarations are appended by `generate`.
pub const fetcher_package_prefix_wit =
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

pub const logger_package_wit =
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
pub const handler_package_wit =
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
pub const postgres_package_prefix_wit =
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

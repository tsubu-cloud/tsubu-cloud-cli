const std = @import("std");
const server_local = @import("server.zig");
const wit_gen = @import("wit_gen.zig");

fn usageAndExit() noreturn {
    std.debug.print(
        \\usage: tsubu_cloud_local <command> ...
        \\
        \\commands:
        \\  run <wasm-module> <config.json>   wasmモジュールをローカルで実行する
        \\  deploy <wasm-module> <config.json> wasmモジュールをデプロイする
        \\  wit <config.json> [wit-dir]        tsubu.json を元に wit/deps/*/package.wit
        \\                                      と (未存在なら) wit/guest.wit を生成する
        \\                                      (wit-dir省略時は "wit")
        \\
    , .{});
    std.process.exit(1);
}

const Command = enum { run, deploy, wit };

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());

    if (args.len < 2) usageAndExit();
    const command = std.meta.stringToEnum(Command, args[1]) orelse usageAndExit();

    switch (command) {
        .run, .deploy => {
            if (args.len < 4) usageAndExit();
            const wasm_module = args[2];
            const config_path = args[3];
            switch (command) {
                .run => try server_local.serve(gpa, init.io, wasm_module, config_path),
                .deploy => {},
                .wit => unreachable,
            }
        },
        .wit => {
            if (args.len < 3) usageAndExit();
            const config_path = args[2];
            const out_dir = if (args.len >= 4) args[3] else "wit";
            try wit_gen.generate(gpa, init.io, config_path, out_dir);
        },
    }
}

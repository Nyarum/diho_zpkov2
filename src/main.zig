const std = @import("std");
const xev = @import("xev");
const zbytes = @import("zbytes");
const actor = @import("actor.zig");
const zbench = @import("zbench");

const Test2 = struct {
    x: u32,

    pub inline fn tag(self: Test2, comptime T: type, comptime name: []const u8) ?zbytes.encdec.Tag(T) {
        const caseString = enum { x };
        const case = std.meta.stringToEnum(caseString, name) orelse return null;
        switch (case) {
            .x => return tagx(self),
        }
    }

    inline fn tagx(self: Test2) zbytes.encdec.Tag(u32) {
        _ = self; // autofix
        return zbytes.encdec.Tag(u32){
            .isLittle = true,
            .fieldOption = zbytes.encdec.FieldOption(u32){
                .isIgnore = false,
                .eq = zbytes.encdec.FieldOptionEq(u32){
                    .eq = 16,
                },
            },
        };
    }
};

const ActorHandler = struct {
    fn init() ActorHandler {
        return ActorHandler{};
    }

    pub fn callback(self: ActorHandler, msg: Test2) void {
        std.debug.print("got msg {any}\n", .{msg});

        _ = self; // autofix
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var loopNew = blk: {
        const loopNew = try allocator.create(xev.Loop);
        loopNew.* = try xev.Loop.init(.{});
        break :blk loopNew;
    };
    defer loopNew.deinit();

    const actorHandler = try actor.Actor(Test2, ActorHandler).init(allocator, "test", "pid", ActorHandler.init());
    defer actorHandler.deinit();

    try actorHandler.start(loopNew);

    _ = try std.Thread.spawn(.{}, loopWait, .{loopNew});
    while (true) {
        std.time.sleep(0.01 * std.time.ns_per_s);
        std.debug.print("send notification\n", .{});
        try actorHandler.send(Test2{ .x = 16 });
    }
}

fn loopWait(loop: *xev.Loop) void {
    std.debug.print("start actors loop\n", .{});
    loop.run(.until_done) catch unreachable;
}

fn benchmarkMyFunction(allocator: std.mem.Allocator) void {
    _ = allocator; // autofix
    // Code to benchmark here
}

test "bench test" {
    var bench = zbench.Benchmark.init(std.testing.allocator, .{});
    defer bench.deinit();
    try bench.add("My Benchmark", benchmarkMyFunction, .{});
    try bench.run(std.io.getStdErr().writer());
}

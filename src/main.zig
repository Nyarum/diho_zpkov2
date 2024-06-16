const std = @import("std");
const xev = @import("xev");
const zbytes = @import("zbytes");
const actor = @import("actor.zig");

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

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var loopNew = try allocator.create(xev.Loop);
    defer loopNew.deinit();

    loopNew.* = try xev.Loop.init(.{});

    const actorHandler = actor.Actor(Test2).init(allocator, "test", "pid");
    try actorHandler.start(loopNew);

    _ = try std.Thread.spawn(.{}, loopWait, .{loopNew});

    while (true) {
        std.time.sleep(1 * std.time.ns_per_s);
        std.debug.print("send notification\n", .{});
        try actorHandler.send(Test2{ .x = 16 });
    }
}

fn loopWait(loop: *xev.Loop) void {
    std.debug.print("start actors loop\n", .{});
    loop.run(.until_done) catch unreachable;
}

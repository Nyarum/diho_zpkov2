const std = @import("std");
const xev = @import("xev");
const zbytes = @import("zbytes");

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
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    const t = Test2{
        .x = 16,
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const res = try zbytes.encdec.encode(allocator, t, std.builtin.Endian.big);
    defer res.deinit();

    std.debug.print("Test 2 {x}\n", .{res.getData()});
}

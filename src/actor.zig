const std = @import("std");
const xev = @import("xev");
const queue = @import("xev/queue.zig");

pub fn Elem(comptime T: type) type {
    return struct {
        const Self = @This();
        next: ?*Self = null,

        value: T,
    };
}

fn Userdata(comptime Msg: type) type {
    return struct {
        queue: *queue.Intrusive(Elem(Msg)),
        allocator: std.mem.Allocator,
    };
}

pub fn Actor(comptime Msg: type) type {
    return struct {
        name: []const u8,
        pid: []const u8,
        asyncHandler: *xev.Async = undefined,
        allocator: std.mem.Allocator = undefined,
        queue: *queue.Intrusive(Elem(Msg)),
        userdata: *Userdata(Msg) = undefined,
        c_wait: *xev.Completion = undefined,

        pub fn init(allocator: std.mem.Allocator, name: []const u8, pid: []const u8) *Actor(Msg) {
            const queueNew = allocator.create(queue.Intrusive(Elem(Msg))) catch unreachable;
            queueNew.init();

            // Create the actor
            const actor = allocator.create(Actor(Msg)) catch unreachable;
            actor.* = Actor(Msg){
                .name = name,
                .pid = pid,
                .allocator = allocator,
                .queue = queueNew,
            };

            return actor;
        }

        pub fn deinit(self: *Actor(Msg)) void {
            self.allocator.destroy(self.queue);
            self.allocator.destroy(self.userdata);
            self.asyncHandler.deinit();
            self.allocator.destroy(self.asyncHandler);
            self.allocator.destroy(self.c_wait);
            self.allocator.destroy(self);
        }

        pub fn start(self: *Actor(Msg), loop: *xev.Loop) !void {
            const asyncImplNew = try self.allocator.create(xev.Async);
            asyncImplNew.* = try xev.Async.init();

            self.asyncHandler = asyncImplNew;

            self.userdata = try self.allocator.create(Userdata(Msg));
            self.userdata.* = Userdata(Msg){
                .queue = self.queue,
                .allocator = self.allocator,
            };

            // Wait
            self.c_wait = try self.allocator.create(xev.Completion);
            asyncImplNew.wait(loop, self.c_wait, Userdata(Msg), self.userdata, (struct {
                fn callback(
                    userdata: ?*Userdata(Msg),
                    _: *xev.Loop,
                    _: *xev.Completion,
                    r: xev.Async.WaitError!void,
                ) xev.CallbackAction {
                    const messagesGet = userdata.?.queue;

                    std.debug.print("test async method\n", .{});
                    //@compileLog("test", userdata.?.queue);

                    if (messagesGet.pop()) |msg| {
                        defer userdata.?.allocator.destroy(msg);

                        std.debug.print("test async msg {any}\n", .{msg});
                    }

                    _ = r catch unreachable;

                    return .rearm;
                }
            }).callback);
        }

        pub fn send(self: *Actor(Msg), msg: anytype) !void {
            const elem = try self.allocator.create(Elem(@TypeOf(msg)));
            elem.* = Elem(@TypeOf(msg)){
                .value = msg,
            };
            self.queue.push(elem);
            try self.asyncHandler.notify();
        }
    };
}

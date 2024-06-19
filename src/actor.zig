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

fn Userdata(comptime Msg: type, comptime Handler: type) type {
    return struct {
        queue: *queue.Intrusive(Elem(Msg)),
        allocator: std.mem.Allocator,
        handler: *Handler = undefined,
    };
}

pub fn Actor(comptime Msg: type, comptime Handler: type) type {
    return struct {
        name: []const u8,
        pid: []const u8,
        asyncHandler: *xev.Async = undefined,
        allocator: std.mem.Allocator = undefined,
        queue: *queue.Intrusive(Elem(Msg)),
        userdata: *Userdata(Msg, Handler) = undefined,
        c_wait: *xev.Completion = undefined,
        handler: *Handler = undefined,

        pub fn init(allocator: std.mem.Allocator, name: []const u8, pid: []const u8, actorHandler: Handler) !*Actor(Msg, Handler) {
            _ = actorHandler; // autofix
            // Create the actor
            const actor = try allocator.create(Actor(Msg, Handler));
            actor.* = Actor(Msg, Handler){
                .name = name,
                .pid = pid,
                .allocator = allocator,
                .queue = try allocator.create(queue.Intrusive(Elem(Msg))),
                .asyncHandler = try allocator.create(xev.Async),
                .c_wait = try allocator.create(xev.Completion),
                .userdata = try allocator.create(Userdata(Msg, Handler)),
                .handler = try allocator.create(Handler),
            };

            actor.queue.init();

            actor.asyncHandler.* = try xev.Async.init();

            actor.userdata.* = Userdata(Msg, Handler){
                .queue = actor.queue,
                .allocator = actor.allocator,
                .handler = actor.handler,
            };

            return actor;
        }

        pub fn deinit(self: *Actor(Msg, Handler)) void {
            self.allocator.destroy(self.queue);
            self.allocator.destroy(self.userdata);
            self.asyncHandler.deinit();
            self.allocator.destroy(self.asyncHandler);
            self.allocator.destroy(self.c_wait);
            self.allocator.destroy(self);
        }

        pub fn start(self: *Actor(Msg, Handler), loop: *xev.Loop) !void {
            self.asyncHandler.wait(loop, self.c_wait, Userdata(Msg, Handler), self.userdata, (struct {
                fn callback(
                    userdata: ?*Userdata(Msg, Handler),
                    _: *xev.Loop,
                    _: *xev.Completion,
                    r: xev.Async.WaitError!void,
                ) xev.CallbackAction {
                    if (userdata) |data| {
                        if (data.queue.pop()) |msg| {
                            defer userdata.?.allocator.destroy(msg);

                            data.handler.callback(msg.value);
                        }
                    }

                    _ = r catch unreachable;

                    return .rearm;
                }
            }).callback);
        }

        pub fn send(self: *Actor(Msg, Handler), msg: anytype) !void {
            const elem = try self.allocator.create(Elem(@TypeOf(msg)));
            elem.* = Elem(@TypeOf(msg)){
                .value = msg,
            };
            self.queue.push(elem);

            try self.asyncHandler.notify();
        }
    };
}

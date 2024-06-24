const std = @import("std");
const testing = std.testing;

pub fn MPSCQueue(comptime T: type) type {
    return struct {
        buffer: []T,
        head: std.atomic.Value(T), // индекс для вставки (производители)
        tail: std.atomic.Value(T), // индекс для извлечения (потребитель)
        allocator: std.mem.Allocator,
        mutex: std.Thread.Mutex,
        cond: std.Thread.Condition,
        capacity: usize,

        pub fn init(allocator: std.mem.Allocator, capacity: usize, init_value: T) *MPSCQueue(T) {
            const buffer = allocator.alloc(T, capacity) catch unreachable;
            const mpscAlloc = allocator.create(MPSCQueue(T)) catch unreachable;
            mpscAlloc.* = MPSCQueue(T){
                .buffer = buffer,
                .head = std.atomic.Value(T).init(init_value),
                .tail = std.atomic.Value(T).init(init_value),
                .allocator = allocator,
                .mutex = std.Thread.Mutex{},
                .cond = std.Thread.Condition{},
                .capacity = capacity,
            };

            return mpscAlloc;
        }

        pub fn deinit(self: *MPSCQueue(T)) void {
            self.allocator.free(self.buffer);
            self.allocator.destroy(self);
        }

        pub fn enqueue(self: *MPSCQueue(T), item: T) !void {
            var head = self.head.fetchAdd(1, .acquire);

            while (true) {
                const next_head = (head + 1);
                const tail = self.tail.load(.acquire);
                if (next_head == tail) {
                    return error.QueueFull;
                }

                if (self.head.cmpxchgWeak(head, next_head, .acquire, .monotonic) != null) {
                    self.buffer[head] = item;
                    self.cond.signal();
                    break;
                }
                head = self.head.load(.acquire);
            }
        }

        pub fn dequeue(self: *MPSCQueue(T)) ?T {
            const tail = self.tail.load(.acquire);
            const head = self.head.load(.acquire);

            //std.debug.print("head: {any} tail: {any}\n", .{ head, tail });

            if (tail == head) {
                return null;
            }

            const item = self.buffer[tail];
            self.tail.store((tail + 1), .release);

            return item;
        }

        pub fn dequeue_blocking(self: *MPSCQueue(T)) ?T {
            self.mutex.lock();
            defer self.mutex.unlock();

            while (true) {
                if (self.dequeue()) |item| {
                    return item;
                }

                self.cond.wait(&self.mutex);
            }
        }

        pub fn count(self: *MPSCQueue(T)) usize {
            const head = self.head.load(.acquire);
            const tail = self.tail.load(.acquire);

            if (head >= tail) {
                return head - tail;
            } else {
                return self.capacity - tail + head;
            }
        }
    };
}

const test_queue_num = 100_000_000;
var global_mutex = std.Thread.Mutex{};
var global_cond = std.Thread.Condition{};

test "MPSCQueue" {
    const allocator = std.testing.allocator;

    const queue = MPSCQueue(usize).init(allocator, test_queue_num * 3, 0);
    defer queue.deinit();

    var thread = try std.Thread.spawn(.{}, run, .{queue});
    var thread2 = try std.Thread.spawn(.{}, run, .{queue});
    var thread4 = try std.Thread.spawn(.{}, run, .{queue});
    var thread3 = try std.Thread.spawn(.{}, dequeRun, .{queue});

    var timer = std.time.Timer.start() catch unreachable;

    thread.join();
    thread2.join();
    thread4.join();

    global_cond.signal();
    thread3.join();

    std.debug.print("count: {any}\n", .{queue.count()});
    try testing.expect(queue.count() == 0);

    const elapsed = timer.lap();
    const delim: u64 = 1000000;
    const milliseconds = elapsed / delim;

    std.debug.print("Taken time {any} ms\n", .{milliseconds});
}

fn run(arg: *MPSCQueue(usize)) !void {
    for (0..test_queue_num) |_| {
        try arg.enqueue(3);
    }
}

fn dequeRun(arg: *MPSCQueue(usize)) !void {
    global_mutex.lock();
    defer global_mutex.unlock();

    const final_count = test_queue_num * 3;

    global_cond.wait(&global_mutex);

    for (0..final_count) |_| {
        _ = arg.dequeue();
    }
}

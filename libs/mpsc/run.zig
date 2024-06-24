const mpsc = @import("mpsc.zig");
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var queue = mpsc.MPSCQueue(usize, 1000000002, 0).init(allocator);
    defer queue.deinit();

    const queueAlloc = try allocator.create(mpsc.MPSCQueue(usize, 1000000002, 0));
    queueAlloc.* = queue;
    defer allocator.destroy(queueAlloc);

    var thread = try std.Thread.spawn(.{}, run, .{queueAlloc});
    var thread2 = try std.Thread.spawn(.{}, run, .{queueAlloc});
    var thread3 = try std.Thread.spawn(.{}, dequeRun, .{queueAlloc});

    var timer = std.time.Timer.start() catch unreachable;

    thread.join();
    thread2.join();
    thread3.join();

    std.debug.print("count: {any}\n", .{queueAlloc.count()});

    // Остановка таймера
    const elapsed = timer.lap();

    // Вывод результата и времени выполнения
    std.debug.print("elapsed: {any}\n", .{elapsed});

    // Преобразование наносекунд в миллисекунды
    const delim: u64 = 1000000;
    const milliseconds = elapsed / delim;

    // Вывод результата
    std.debug.print("Formatted time: {any} ms\n", .{milliseconds});
}

fn run(arg: *mpsc.MPSCQueue(usize, 1000000002, 0)) !void {
    for (0..100_000_00) |_| {
        try arg.enqueue(3);
    }

    std.debug.print("count 2: {any}\n", .{arg.count()});
}

fn dequeRun(arg: *mpsc.MPSCQueue(usize, 1000000002, 0)) !void {
    const final_count = 100_000_00 * 2;

    var i: usize = 0;
    while (arg.dequeue_blocking()) |v| {
        _ = v; // autofix
        i += 1;
        if (i >= final_count) {
            break;
        }
    }
}

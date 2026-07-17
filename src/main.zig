const std = @import("std");
const Io = std.Io;

const REPL = @import("repl.zig");
const Closed = Io.QueueClosedError.Closed;

pub fn main(init: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const gpa = arena.allocator();
    const io = init.io;

    // start repl
    while (true) {
        REPL.userInput(io, gpa) catch |err| switch (err) {
            error.NotFound => std.debug.print("Command not found. Try 'help'.\n", .{}),
            error.Exit => break,
            else => std.debug.print("Error: {any}\n", .{err}),
        };
    }
}


const std = @import("std");
const Io = std.Io;
const assert = std.debug.assert;
const Protein = @import("protein.zig").Protein;
const proteinProducer = @import("protein.zig").proteinProducer;
const proteinConsumer = @import("protein.zig").proteinConsumer;
const REPL = @import("repl.zig");
const AutoHashMap = std.hash_map.AutoHashMap;
const Closed = Io.QueueClosedError.Closed;

pub fn main(init: std.process.Init) !void {
    // Set up allocator.
    const gpa = init.gpa;
    // Set up I/O implementation.
    const io = init.io;
    // Access CLI arguments
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    var filename: []const u8 = "sequences/mature.fa"; // set a default
    // Check for args[1] and assign filename
    if (args.len > 1) {
        filename = args[1];
    } else {
        std.debug.print("No file argument given...\nUsing default file.\n", .{});
    }

    // Create Protein queue
    var queue: Io.Queue(Protein) = .init(&.{});
    // Call proteinProducer
    var producer_task = try io.concurrent(proteinProducer, .{
        io, gpa, &queue, filename,
    });
    defer producer_task.cancel(io) catch {};

    var myProtein: Protein = undefined;
    defer myProtein.deinit(gpa);

    while (true) {
    var consumer_task = try io.concurrent(proteinConsumer, .{ io, &queue });
    defer _ = consumer_task.cancel(io) catch {};
        if (consumer_task.await(io)) |p| {
            myProtein = p;
    } else |err| {
        std.debug.print("an error was returned: {any}\n", .{err});
        break;
        }
        std.debug.print("protein: {any}\n\n\n", .{myProtein});        
    }

    // test repl
    while (true) {
        REPL.userInput(io, gpa) catch {
            std.debug.print("The input line was too long.\n", .{});
        };
    }
}

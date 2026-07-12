const std = @import("std");
const Io = std.Io;
const assert = std.debug.assert;
const Protein = @import("protein.zig").Protein;
const proteinProducer = @import("protein.zig").proteinProducer;
const proteinConsumer = @import("protein.zig").proteinConsumer;
const REPL = @import("repl.zig");
const AutoHashMap = std.hash_map.AutoHashMap;

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

    // Retrieve protein from the queue
    // Call proteinConsumer
    var consumer_task = try io.concurrent(proteinConsumer, .{ io, &queue });
    defer _ = consumer_task.cancel(io) catch {};
    var myProtein = try consumer_task.await(io);
    defer myProtein.deinit(gpa);

    // Print stuff
    std.debug.print("Protein object is: {any}\n", .{myProtein});
    std.debug.print("Length is: {d}\n", .{myProtein.sequence.len});

    // test repl
    while (true) {
        REPL.userInput(io, gpa) catch {
            std.debug.print("The input line was too long.\n", .{});
        };
    }
}

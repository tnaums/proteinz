const std = @import("std");
const Io = std.Io;
const Protein = @import("protein.zig").Protein;
const proteinProducer = @import("protein.zig").proteinProducer;
const proteinConsumer = @import("protein.zig").proteinConsumer;
const REPL = @import("repl.zig");
const Closed = Io.QueueClosedError.Closed;

pub fn main(init: std.process.Init) !void {
    //    const gpa = init.gpa;
    var debug = std.heap.DebugAllocator(.{}){};
    const gpa = debug.allocator();
    const io = init.io;
    const args = try init.minimal.args.toSlice(init.arena.allocator());

    var filename: []const u8 = "sequences/mature.fa"; // set a default

    // Check for args[1] and assign filename
    if (args.len > 1) {
        filename = args[1];
    } else {
        std.debug.print("No file argument given...\nUsing default file {s}.\n", .{filename});
    }

    // Create Protein queue
    var queue: Io.Queue(Protein) = .init(&.{});
    // Start proteinProducer
    var producer_task = try io.concurrent(proteinProducer, .{
        io, gpa, &queue, filename,
    });
    defer producer_task.cancel(io) catch {};

    var myProtein: Protein = undefined;
    defer myProtein.deinit(gpa);

    var counter: u16 = 0;
    while (true) {
        var consumer_task = try io.concurrent(proteinConsumer, .{ io, &queue });
        defer _ = consumer_task.cancel(io) catch {};
        if (consumer_task.await(io)) |p| {
            myProtein = p;
        } else |err| {
            std.debug.print("Found {any}\n", .{err});
            break;
        }
        std.debug.print("protein: {s}\n", .{myProtein.header});
        std.debug.print("sequence: {s}\n", .{myProtein.sequence});
        std.debug.print("mass: {d:.3}\n", .{myProtein.mass});
        if (myProtein.sequence.len > counter) { counter = @intCast(myProtein.sequence.len); }
    }
    std.debug.print("The longest protein has {d} amino acids.\n", .{counter});

    // test repl
    while (true) {
        REPL.userInput(io, gpa) catch {
            std.debug.print("The input line was too long.\n", .{});
        };
    }
}

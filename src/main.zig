const std = @import("std");
const Io = std.Io;
const Protein = @import("protein.zig").Protein;
const proteinProducer = @import("protein.zig").proteinProducer;
const proteinConsumer = @import("protein.zig").proteinConsumer;
const REPL = @import("repl.zig");
const Closed = Io.QueueClosedError.Closed;

pub fn main(init: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const gpa = arena.allocator();
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

    var counter: u16 = 0;
    var maxMass: f32 = 0.0;
    var biggestProtein: Protein = undefined;
    var longestProtein: Protein = undefined;
    
    while (true) {
        var myProtein: *const Protein = undefined;

        var consumer_task = try io.concurrent(proteinConsumer, .{ io, &queue });
        defer _ = consumer_task.cancel(io) catch {};
        if (consumer_task.await(io)) |*p| {
            myProtein = p;
        } else |err| {
            std.debug.print("Finished parsing sequence file: {any}\n", .{err});
            break;
         }
        std.debug.print("protein: {s}\n", .{myProtein.header});
        std.debug.print("sequence: {s}\n", .{myProtein.sequence});
        std.debug.print("mass: {d:.3}\n", .{myProtein.mass});
        if (myProtein.sequence.len > counter) {
            counter = @intCast(myProtein.sequence.len);
            longestProtein = myProtein.*;
        }
        if (myProtein.mass > maxMass) {
            maxMass = myProtein.mass;
            biggestProtein = myProtein.*;
        }
    }
    std.debug.print("The longest protein has {d} amino acids.\n", .{counter});


    std.debug.print("\nThe protein with the largest mass was:\n", .{});
    std.debug.print("{s}\n", .{biggestProtein.header});
    std.debug.print("It has a mass of {d} kDa.\n", .{maxMass});    

    std.debug.print("\nThe longest protein was:\n", .{});
    std.debug.print("{s}\n", .{longestProtein.header});
    std.debug.print("It has {d} amino acids.\n", .{counter});    


    // test repl
    while (true) {
        REPL.userInput(io, gpa) catch |err| switch (err) {
            error.NotFound => std.debug.print("Command not found. Try 'help'.\n", .{}),
            error.Exit => break,
            else => std.debug.print("Some other error.\n", .{}),
        };
    }
}


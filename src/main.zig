const std = @import("std");
const assert = std.debug.assert;
const Protein = @import("protein.zig").Protein;
const REPL = @import("repl.zig");
const AutoHashMap = std.hash_map.AutoHashMap;

const arguments = enum { repl, command };

pub fn main(init: std.process.Init) !void {
    // Set up allocator.
    const gpa = init.gpa;
    // Set up I/O implementation.
    const io = init.io;
    std.debug.print("Type of gpa: {}\n", .{@TypeOf(gpa)});
    // Access CLI arguments
    const args = try init.minimal.args.toSlice(
        init.arena.allocator()
    );

    // looping over cli arguments, just for fun
    for (args, 0..) |arg, idx| {
        std.debug.print("{d}: {s}\n", .{ idx, arg });
    }
    std.debug.print("\n\n", .{});

    // Use enum and args[1] to decide what to do.
    if (args.len > 1) {
        const command = std.meta.stringToEnum(arguments, args[1]) orelse {
            return error.InvalidChoice;
        };
        switch (command) {
            .repl => std.debug.print("You requested a repl!\n", .{}),
            .command => std.debug.print("You requested a command interface!\n", .{}),
        }
    }

    var header: []u8 = undefined;
    var sequence: std.ArrayList(u8) = .empty;
    defer sequence.deinit(gpa);

    // Open the file with error checking.
    if (std.Io.Dir.cwd().openFile(io, "sequences/mature.fa", .{ .mode = .read_only, .lock = .exclusive })) |file| {
        defer file.close(io);
        var buf: [1024]u8 = undefined; // must be big enough for longest line
        var reader: std.Io.File.Reader = file.reader(io, &buf);
        while (try reader.interface.takeDelimiter('\n')) |line| {
            if (line[0] == '>') {
                header = line;
            } else {
                try sequence.appendSlice(gpa, line);
            }
        }
    } else |err| switch (err) {
        error.FileNotFound, error.AccessDenied => {
            std.debug.print("unable to open file: {}\n", .{err});
        },
        else => |e| return e,
    }

    // Print some stuff
    std.debug.print("Header: {s}\n", .{header});
    std.debug.print("Sequence: {s}\n", .{sequence.items});
    std.debug.print("Sequence length is: {d}\n", .{sequence.items.len});
    std.debug.print("Buffer capacity is: {d}\n", .{sequence.capacity});

    // Create a Protein
    const myProtein: Protein = Protein.init(header, sequence.items);
    std.debug.print("Protein object is: {any}\n", .{myProtein});

    // test repl
    while (true) {
        REPL.userInput(io, gpa) catch {
            std.debug.print("The input line was too long.\n", .{});
        };
    }

}

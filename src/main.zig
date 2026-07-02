const std = @import("std");
const assert = std.debug.assert;
const Protein = @import("protein.zig").Protein;
const AutoHashMap = std.hash_map.AutoHashMap;

pub fn main(init: std.process.Init) !void {
    // Set up allocator.
//    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
//    defer assert(debug_allocator.deinit() == .ok);
    //    const gpa = debug_allocator.allocator();
    const gpa = init.gpa;

    // Set up our I/O implementation.
    // var threaded: std.Io.Threaded = .init(gpa, .{});
    // defer threaded.deinit();
    // const io = threaded.io();
    const io = init.io;
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
    std.debug.print("Type: {s}\n", .{@typeName(@TypeOf(sequence.items))});
    std.debug.print("Sequence length is: {d}\n", .{sequence.items.len});
    std.debug.print("Buffer capacity is: {d}\n", .{sequence.capacity});

    // Create a Protein
    const myProtein: Protein = Protein.init(header, sequence.items);
    std.debug.print("Protein object is: {any}\n", .{myProtein});


}

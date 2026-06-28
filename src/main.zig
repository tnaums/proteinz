const std = @import("std");
const assert = std.debug.assert;
// init: std.process.Init

const Protein = struct {
    header: []const u8,
    sequence: []const u8,

    fn init(header: []const u8, sequence: []const u8) Protein {
        return Protein {
            .header = header,
            .sequence = sequence,
        };
    }
};

pub fn main() !void {
    std.debug.print("Welcome to proteinz!\n", .{});
    // Set up allocator.
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer assert(debug_allocator.deinit() == .ok);
    const gpa = debug_allocator.allocator();
    
    // Set up our I/O implementation.
    var threaded: std.Io.Threaded = .init(gpa, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var header: [] u8 = undefined;
    var sequence: std.ArrayList(u8) = .empty;
    defer sequence.deinit(gpa);
    
    // Open the file with error checking.
    if (std.Io.Dir.cwd().openFile(io, "sequences/mature.pep", .{
        .mode = .read_only,
        .lock = .exclusive
    })) |file| {
        defer file.close(io);
        var buf: [1024]u8 = undefined; // must be big enough for longest line
        var reader: std.Io.File.Reader = file.reader(io, &buf);
        while (try reader.interface.takeDelimiter('\n')) |line| { // not advisable to auto-propagate; see below...
//            std.debug.print("line: {s}\n", .{line});
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
    std.debug.print("Header: {s}\n", .{header});
    std.debug.print("Sequence: {s}\n", .{sequence.items});
    std.debug.print("Type: {s}\n", .{@typeName(@TypeOf(sequence.items))});
    std.debug.print("Sequence length is: {d}\n", .{sequence.items.len});
    std.debug.print("Buffer capacity is: {d}\n", .{sequence.capacity});
    const myProtein: Protein = Protein.init( header, sequence.items );
    std.debug.print("Protein object is: {any}", .{myProtein});
}




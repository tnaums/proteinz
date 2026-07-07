const std = @import("std");
const Io = std.Io;

pub fn userInput(io: Io, gpa: std.mem.Allocator) !void {
    // Create a writer interface to standard out.
    var stdout_writer = std.Io.File.stdout().writer(io, &.{});
    const stdout = &stdout_writer.interface;
    // Create a reader interface for standard in.
    var buffer: [80]u8 = undefined;    
    var stdin_reader = std.Io.File.stdin().reader(io, &buffer);
    const stdin = &stdin_reader.interface;

    // Print the prompt.
    try stdout.print("\nproteinz > ", .{});

    // Get a line of input. Function returns both error union and optional
    const line_input = try stdin.takeDelimiter('\n') orelse "default";

    // Print it back out.
    try stdout.print("input line: {s}\n", .{line_input});

    // parse into words
    try cleanInput(line_input, gpa);
}

fn cleanInput(line_input: []const u8, gpa: std.mem.Allocator) !void {
    const whitespace = " \t\n\r";
    const trimmed = std.mem.trim(u8, line_input, whitespace);
    const lower = try std.ascii.allocLowerString(gpa, trimmed);
    defer gpa.free(lower);
    var it = std.mem.splitScalar(u8, lower, ' ');
    while (it.next()) |part| {
        if (part.len > 0) {
            std.debug.print("Part: {s}\n", .{part});
            std.debug.print("length: {d}\n", .{part.len});
        }
    }
}

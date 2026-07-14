const std = @import("std");
const Io = std.Io;

const Command = enum {
    help,
    exit,
};

const commandMap: std.EnumArray(Command, f32) = .init(.{
    .help = 42,
    .exit = 63,
});

pub fn userInput(io: Io, gpa: std.mem.Allocator) !void {
    var out_buffer: [80]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &out_buffer);
    const stdout = &stdout_writer.interface;

    var in_buffer: [80]u8 = undefined;    
    var stdin_reader = std.Io.File.stdin().reader(io, &in_buffer);
    const stdin = &stdin_reader.interface;

    // Print the prompt.
    try stdout.print("\nproteinz > ", .{});
    try stdout.flush();

    // Get a line of input. Function returns both error union and optional
    const line_input = try stdin.takeDelimiter('\n') orelse "default";

    // Print it back out.
    try stdout.print("input line: {s}\n", .{line_input});
    try stdout.flush();

    // parse into words
    try cleanInput(line_input, gpa);
}

fn cleanInput(line_input: []const u8, gpa: std.mem.Allocator) !void {
    const whitespace = " \t\n\r";
    const trimmed = std.mem.trim(u8, line_input, whitespace);
    const lower = try std.ascii.allocLowerString(gpa, trimmed);
    defer gpa.free(lower);
    var it = std.mem.tokenizeSequence(u8, lower, " ");
    while (it.next()) |part| {
        // add to a slice of strings
        const k = std.meta.stringToEnum(Command, part);
        if (k) |key| {
            std.debug.print("Command {s} value is: {d}\n", .{ part, commandMap.get(key)});
        }
        std.debug.print("Part: {s}\n", .{part});
        std.debug.print("length: {d}\n", .{part.len});

    }
}

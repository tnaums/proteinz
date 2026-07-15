const std = @import("std");
const Io = std.Io;

const CommandError = error {
    NotFound,
    Exit,
};

const Command = enum {
    help,
    exit,
};

const descriptionMap: std.EnumArray(Command, []const u8) = .init(.{
    .help = "displays a help message",
    .exit = "exit proteinz",
});

const commandMap: std.EnumArray(Command, *const fn() CommandError!void) = .init(.{
    .help = commandHelp,
    .exit = commandExit,
});

const nameMap: std.EnumArray(Command, []const u8) = .init(.{
    .help = "help",
    .exit = "exit",
});

pub fn commandExit() CommandError!void {
    std.debug.print("Please exit in an orderly fashion.\n", .{});
    return CommandError.Exit;
}

pub fn commandHelp() CommandError!void {
    std.debug.print("\nWelcome to proteinz, the protein repl!\n------\nUsage:\n------\n", .{});
    inline for (std.enums.values(Command)) |e| {
        std.debug.print("{s}: ", .{nameMap.get(e)});
        std.debug.print("{s}\n", .{descriptionMap.get(e)});
    }

}

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

    // parse into words
    const cmd = try cleanInput(line_input, gpa);
    const c = commandMap.get(cmd);
    try c();
}

fn cleanInput(line_input: []const u8, gpa: std.mem.Allocator) !Command {
    const whitespace = " \t\n\r";
    const trimmed = std.mem.trim(u8, line_input, whitespace);
    const lower = try std.ascii.allocLowerString(gpa, trimmed);
    defer gpa.free(lower);
    var it = std.mem.tokenizeSequence(u8, lower, " ");
    var cmd: Command = undefined;
    
    if (it.next()) |first| {
        const k = std.meta.stringToEnum(Command, first); // ?T
        if (k) |key| {
            cmd = key;
        } else {
            return CommandError.NotFound;
        }
        
    }

    if (it.next()) |second| {
        std.debug.print("command argument is: {s}\n", .{second});
    }
    return cmd;
}

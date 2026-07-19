const std = @import("std");
const Io = std.Io;
const Protein = @import("protein.zig").Protein;
const proteinProducer = @import("protein.zig").proteinProducer;
const proteinConsumer = @import("protein.zig").proteinConsumer;
const proteomeParser = @import("protein.zig").proteomeParser;
const ProteinArray = @import("protein.zig").ProteinArray;
const uniprotGET = @import("uniprot.zig").uniprotGET;

const CommandError = error{
    NotFound,
    Exit,
};

const Command = enum {
    parse,
    uniprot,
    help,
    exit,
};

const descriptionMap: std.EnumArray(Command, []const u8) = .init(.{
    .parse = "parse a proteome",
    .uniprot = "uniprot <accession>",
    .help = "displays a help message",
    .exit = "exit proteinz",
});

const commandMap: std.EnumArray(Command, *const fn (io: Io, gpa: std.mem.Allocator, stdout: *Io.Writer, argument: ?[]const u8) CommandError!void) = .init(.{
    .parse = commandParse,
    .uniprot = commandUniprot,
    .help = commandHelp,
    .exit = commandExit,
});

const nameMap: std.EnumArray(Command, []const u8) = .init(.{
    .parse = "parse",
    .uniprot = "uniprot",
    .help = "help",
    .exit = "exit",
});

pub fn commandUniprot(io: Io, gpa: std.mem.Allocator, stdout: *Io.Writer, argument: ?[]const u8) CommandError!void {
    _ = stdout;
    const accession: []const u8 = argument orelse "P29022";
    uniprotGET(io, gpa, accession) catch {};
}

pub fn commandParse(io: Io, gpa: std.mem.Allocator, stdout: *Io.Writer, argument: ?[]const u8) CommandError!void {
    _ = stdout;
    _ = argument;
    const filename: []const u8 = "sequences/proteome_truncated.fa"; // set a default
    selectFile(io) catch {};

    var queue: Io.Queue(Protein) = .init(&.{});
    // Start proteinProducer
    var producer_task = io.concurrent(proteinProducer, .{
        io, gpa, &queue, filename,
    }) catch unreachable;
    defer producer_task.cancel(io) catch {};

    var counter: u16 = 0;
    var maxMass: f32 = 0.0;
    var biggestProtein: Protein = undefined;
    var longestProtein: Protein = undefined;

    while (true) {
        var myProtein: *const Protein = undefined;

        var consumer_task = io.concurrent(proteinConsumer, .{ io, &queue }) catch unreachable;
        defer _ = consumer_task.cancel(io) catch {};
        if (consumer_task.await(io)) |*p| {
            myProtein = p;
        } else |err| {
            std.debug.print("Finished parsing sequence file: {any}\n", .{err});
            break;
        }
        std.debug.print("protein: {s}\n", .{myProtein.header});
        std.debug.print("sequence: {s}\n", .{myProtein.sequence});
        std.debug.print("mass: {d:.3}\n\n", .{myProtein.mass});
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

    std.debug.print("Parsing proteome file...\n", .{});
}

pub fn commandExit(io: Io, gpa: std.mem.Allocator, stdout: *Io.Writer, argument: ?[]const u8) CommandError!void {
    //    _ = stdout;
    _ = argument;
    _ = io;
    _ = gpa;
    stdout.print("exiting repl...\n", .{}) catch {};
    stdout.flush() catch {};
    return CommandError.Exit;
}

pub fn commandHelp(io: Io, gpa: std.mem.Allocator, stdout: *Io.Writer, argument: ?[]const u8) CommandError!void {
    _ = argument;
    _ = io;
    _ = gpa;
    stdout.print("\nWelcome to proteinz, the protein repl!\n------\nUsage:\n------\n", .{}) catch {};
    inline for (std.enums.values(Command)) |e| {
        stdout.print("{s:>8}: ", .{nameMap.get(e)}) catch {};
        stdout.print("{s}\n", .{descriptionMap.get(e)}) catch {};
        stdout.flush() catch {};
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
    const input = try cleanInput(line_input, gpa);
    const c = commandMap.get(input[0]);
    try c(io, gpa, stdout, input[1]);
}

fn cleanInput(line_input: []const u8, gpa: std.mem.Allocator) !struct{ Command, ?[]u8 } {
    const whitespace = " \t\n\r";
    const trimmed = std.mem.trim(u8, line_input, whitespace);
    defer gpa.free(trimmed);
    var it = std.mem.tokenizeSequence(u8, trimmed, " ");
    var cmd: Command = undefined;
    var argument: []u8 = undefined;
    if (it.next()) |first| {
        const lower = try std.ascii.allocLowerString(gpa, first);
        const k = std.meta.stringToEnum(Command, lower); // ?T
        if (k) |key| {
            cmd = key;
        } else {
            return CommandError.NotFound;
        }
    }

    if (it.next()) |second| {
        argument = try gpa.alloc(u8, second.len);
        @memcpy(argument, second);
        std.debug.print("in cleanInput: {s}\n", .{argument});
    } else {
        argument = "";
    }
    
    return .{ cmd, argument };
}

fn selectFile(io: Io) !void {
    const cwd = std.Io.Dir.cwd();
    const dir = try cwd.openDir(io, "sequences", .{ .iterate = true });
    var it = dir.iterate();
    while (try it.next(io)) |entry| {
        std.debug.print("File name: {s}\n", .{entry.name});
    }
    //    try stdout.flush();
}

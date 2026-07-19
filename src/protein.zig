const std = @import("std");
const Io = std.Io;
const expect = std.testing.expect;
const Closed = Io.QueueClosedError.Closed;

test "testing Protein creation" {
    const allocator = std.testing.allocator;
    const header: []const u8 = ">fake_protein|Escherichia_graminicola";
    const sequence: []const u8 = "APAEECSSTKTSPAKSGNSPVPKTFGLVALRSASPIHFTHFSATENGFLLGLPADKQNAT";
    const p: *Protein = try Protein.init(allocator, header, sequence);
    defer p.deinit(allocator);
    try expect(p.sequence.len == 60);
}

const AminoAcid = enum {
    A,
    C,
    D,
    E,
    F,
    G,
    H,
    I,
    K,
    L,
    M,
    N,
    P,
    Q,
    R,
    S,
    T,
    V,
    W,
    Y,
};

const massMap: std.EnumArray(AminoAcid, f32) = .init(.{
    .A = 71.07855,
    .C = 103.14464,
    .D = 115.08826,
    .E = 129.11504,
    .F = 147.17571,
    .G = 57.05177,
    .H = 137.14062,
    .I = 113.15890,
    .K = 128.17358,
    .L = 113.15890,
    .M = 131.19820,
    .N = 114.10354,
    .P = 97.11623,
    .Q = 128.13032,
    .R = 156.18707,
    .S = 87.07796,
    .T = 101.10474,
    .V = 99.13211,
    .W = 186.21220,
    .Y = 163.17512,
});

pub const Protein = struct {
    header: []u8,
    sequence: []u8,
    mass: f32,

    pub fn init(allocator: std.mem.Allocator, header: []const u8, sequence: []const u8) !*Protein {
        // Allocate memory for the struct.
        const protein_ptr = try allocator.create(Protein);
        errdefer allocator.destroy(protein_ptr);
        // Allocate memory for the header
        protein_ptr.header = try allocator.alloc(u8, header.len);
        @memcpy(protein_ptr.header, header);
        // Allocate memory for the sequence
        protein_ptr.sequence = try allocator.alloc(u8, sequence.len);
        @memcpy(protein_ptr.sequence, sequence);
        // Calculate and store mass
        protein_ptr.mass = calculateMass(sequence);

        return protein_ptr;
    }

    pub fn deinit(self: *Protein, allocator: std.mem.Allocator) void {
        allocator.free(self.sequence);
        allocator.free(self.header);

        allocator.destroy(self);
    }

    fn calculateMass(sequence: []const u8) f32 {
        var mass: f32 = 18.0;
        for (sequence) |aa| {
            const k = std.meta.stringToEnum(AminoAcid, &[_]u8{aa});
            if (k) |key| {
                mass += massMap.get(key);
            } else if (aa == '*') {
                return mass / 1000; // stop codon, we are done
            } else {
                return 0.0; // something went wrong
            }
        }

        return mass / 1000;
    }
};

pub fn proteinProducer(
    io: Io,
    allocator: std.mem.Allocator,
    queue: *Io.Queue(Protein),
    filename: []const u8,
) !void {
    var header: std.ArrayList(u8) = .empty;
    defer header.deinit(allocator);
    var sequence: std.ArrayList(u8) = .empty;
    defer sequence.deinit(allocator);
    var startFlag: bool = true;
    defer queue.close(io);

    // Open the file with error checking.
    if (std.Io.Dir.cwd().openFile(io, filename, .{ .mode = .read_only, .lock = .exclusive })) |file| {
        defer file.close(io);
        var buf: [100]u8 = undefined; // must be big enough for longest line
        var reader: std.Io.File.Reader = file.reader(io, &buf);
        // Fasta parser, puting each Protein struct into the queue
        while (try reader.interface.takeDelimiter('\n')) |line| {
            if (line.len == 0) {
                continue;
            }
            if (line[0] == '>') {
                if (!startFlag) {
                    const p: *Protein = try .init(allocator, header.items, sequence.items);
                    try queue.putOne(io, p.*);
                    sequence.clearRetainingCapacity();
                    header.clearRetainingCapacity();
                }
                try header.appendSlice(allocator, line);
                startFlag = false;
            } else {
                try sequence.appendSlice(allocator, line);
            }
        }
    } else |err| switch (err) {
        error.FileNotFound, error.AccessDenied => {
            std.debug.print("unable to open file: {}\n", .{err});
        },
        else => |e| return e,
    }

    const p: *Protein = try .init(allocator, header.items, sequence.items);
    try queue.putOne(io, p.*);
}

pub fn proteinConsumer(
    io: Io,
    queue: *Io.Queue(Protein),
) !Protein {
    const value = queue.getOne(io) catch |err| {
        return err;
    };
    return value;
}

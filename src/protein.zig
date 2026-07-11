const std = @import("std");
const Io = std.Io;
const expect = std.testing.expect;

test "testing Protein creation" {
    const io = std.testing.io;
    const allocator = std.testing.allocator;
//    const header: []const u8 = ">fake_protein|Escherichia_graminicola";
//    const sequence: []const u8 = "APAEECSSTKTSPAKSGNSPVPKTFGLVALRSASPIHFTHFSATENGFLLGLPADKQNAT";
    const p: *Protein = try Protein.init(io, allocator, "sequences/mature.fa");
    defer p.deinit(allocator);
    try expect(p.sequence.len == 189);
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

const massMap2: std.EnumMap(AminoAcid, f32) = .init(.{
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

const massMap3 = blk: {
    var map: [90]f32 = undefined; // 'Y' is 89
    map['A'] = 71.07855;
    map['C'] = 103.14464;
    map['D'] = 115.08826;
    map['E'] = 129.11504;
    map['F'] = 147.17571;
    map['G'] = 57.05177;
    map['H'] = 137.14062;
    map['I'] = 113.15890;
    map['K'] = 128.17358;
    map['L'] = 113.15890;
    map['M'] = 131.19820;
    map['N'] = 114.10354;
    map['P'] = 97.11623;
    map['Q'] = 128.13032;
    map['R'] = 156.18707;
    map['S'] = 87.07796;
    map['T'] = 101.10474;
    map['V'] = 99.13211;
    map['W'] = 186.21220;
    map['Y'] = 163.17512;
    break :blk map;
};

pub const ProteinArray = std.MultiArrayList(Protein);

pub const Protein = struct {
    header: []u8,
    sequence: []u8,
    mass: f32,

    pub fn init(io: Io, allocator: std.mem.Allocator, filename: []const u8) !*Protein {
        var header: []u8 = undefined;
        var sequence: std.ArrayList(u8) = .empty;
        defer sequence.deinit(allocator);

        // Open the file with error checking.
        if (std.Io.Dir.cwd().openFile(io, filename, .{ .mode = .read_only, .lock = .exclusive })) |file| {
            defer file.close(io);
            var buf: [1024]u8 = undefined; // must be big enough for longest line
            var reader: std.Io.File.Reader = file.reader(io, &buf);
            while (try reader.interface.takeDelimiter('\n')) |line| {
                if (line[0] == '>') {
                    header = line;
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

        // Allocate memory for the struct.
        const protein_ptr = try allocator.create(Protein);
        errdefer allocator.destroy(protein_ptr);
        // Allocate memory for the header
        protein_ptr.header = try allocator.alloc(u8, header.len);
        @memcpy(protein_ptr.header, header);
        // Allocate memory for the sequence
        protein_ptr.sequence = try allocator.alloc(u8, sequence.items.len);
        @memcpy(protein_ptr.sequence, sequence.items);
        // Calculate and store mass
        protein_ptr.mass = calculateMass2(sequence.items);

        // trying out ProteinArray for creating proteome
        var proteome = ProteinArray{};
        defer proteome.deinit(allocator);
        try proteome.append(allocator, .{
            .header = header, .sequence = sequence.items, .mass = calculateMass2(sequence.items)
        });
        for (proteome.items(.header)) |*header2| {
            std.debug.print("Header: {s}\n", .{header2.*});
        }
        
        return protein_ptr;
    }

    pub fn deinit(self: *Protein, allocator: std.mem.Allocator) void {
        // Free sequence and header memory
        allocator.free(self.sequence);
        allocator.free(self.header);
        // Destroy the struct
        allocator.destroy(self);
    }

    fn calculateMass(sequence: []const u8) f32 {
        var mass: f32 = 18.0;
        for (sequence) |aa| {
            mass += massMap3[aa];
        }

        return mass / 1000;
    }

    fn calculateMass2(sequence: []const u8) f32 {
        var mass: f32 = 18.0;
        for (sequence) |aa| {
            const k = std.meta.stringToEnum(AminoAcid, &[_]u8{aa});
            if (k) |key| {
                mass += massMap2.get(key) orelse unreachable;
            }
        }

        return mass / 1000;
    }
};




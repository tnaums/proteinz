const std = @import("std");
const expect = std.testing.expect;

test "testing Protein creation" {
    const allocator = std.testing.allocator;
    const header: []const u8 = ">fake_protein|Escherichia_graminicola";
    const sequence: []const u8 = "APAEECSSTKTSPAKSGNSPVPKTFGLVALRSASPIHFTHFSATENGFLLGLPADKQNAT";
    const p: *Protein = try Protein.init(allocator, header, sequence);
    defer p.deinit(allocator);
    try expect(p.sequence.len == 60);
}

pub const Protein = struct {
    header: []u8,
    sequence: []u8,
    mass: f32,

    pub fn init(allocator: std.mem.Allocator, header: []const u8, sequence: []const u8) std.mem.Allocator.Error!*Protein {
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
        // Free sequence and header memory
        allocator.free(self.sequence);
        allocator.free(self.header);
        // Destroy the struct
        allocator.destroy(self);
    }

    fn calculateMass(sequence: []const u8) f32 {
        var mass: f32 = 18.0;
        for (sequence) |aa| {
            switch (aa) {
                'A' => {
                    mass += 71.07855;
                },
                'C' => {
                    mass += 103.14464;
                },
                'D' => {
                    mass += 115.08826;
                },
                'E' => {
                    mass += 129.11504;
                },
                'F' => {
                    mass += 147.17571;
                },
                'G' => {
                    mass += 57.05177;
                },
                'H' => {
                    mass += 137.14062;
                },
                'I' => {
                    mass += 113.15890;
                },
                'K' => {
                    mass += 128.17358;
                },
                'L' => {
                    mass += 113.15890;
                },
                'M' => {
                    mass += 131.19820;
                },
                'N' => {
                    mass += 114.10354;
                },
                'P' => {
                    mass += 97.11623;
                },
                'Q' => {
                    mass += 128.13032;
                },
                'R' => {
                    mass += 156.18707;
                },
                'S' => {
                    mass += 87.07796;
                },
                'T' => {
                    mass += 101.10474;
                },
                'V' => {
                    mass += 99.13211;
                },
                'W' => {
                    mass += 186.21220;
                },
                'Y' => {
                    mass += 163.17512;
                },
                else => {
                    return 0.0;
                }, // if non-standard aa found, return zero
            }
        }
        return mass / 1000;
    }
};

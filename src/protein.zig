const std = @import("std");

pub const Protein = struct {
    header: []const u8,
    sequence: []const u8,

    pub fn init(header: []const u8, sequence: []const u8) Protein {
        return Protein{
            .header = header,
            .sequence = sequence,
        };
    }
};

const std = @import("std");

pub const Protein = struct {
    header: []const u8,
    sequence: []const u8,
    mass: f32,

    pub fn init(header: []const u8, sequence: []const u8) Protein {
        return Protein{
            .header = header,
            .sequence = sequence,
            .mass = calculateMass(sequence),
        };
    }

    fn calculateMass(sequence: []const u8) f32 {
        var mass: f32 = 18.0;
        for (sequence) |aa| {
            switch (aa) {
                'A' => { mass += 71.07855; },
                'C' => { mass += 103.14464; },
                'D' => { mass += 115.08826; },
                'E' => { mass += 129.11504; },
                'F' => { mass += 147.17571; },
                'G' => { mass += 57.05177; },
                'H' => { mass += 137.14062; },
                'I' => { mass += 113.15890; },
                'K' => { mass += 128.17358; },
                'L' => { mass += 113.15890; },
                'M' => { mass += 131.19820; },
                'N' => { mass += 114.10354; },
                'P' => { mass += 97.11623; },
                'Q' => { mass += 128.13032; },
                'R' => { mass += 156.18707; },
                'S' => { mass += 87.07796; },
                'T' => { mass += 101.10474; },
                'V' => { mass += 99.13211; },
                'W' => { mass += 186.21220; },
                'Y' => { mass += 163.17512; },
                else => { unreachable; },
            }
        }
        return mass / 1000;
    }
};

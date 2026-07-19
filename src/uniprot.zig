const std = @import("std");
const Io = std.Io;
const print = std.debug.print;
const http = std.http;
const base = "https://www.ebi.ac.uk/proteins/api/proteins/";


pub fn uniprotGET(io: Io, gpa: std.mem.Allocator, accession: []const u8) !void {
    std.debug.print("in uniprotGET, accession is: {s}\n", .{accession});
    const complete = try std.fmt.allocPrint(gpa, "{s}{s}", .{ base, accession });
    defer gpa.free(complete);
    
    var client: http.Client = .{ .allocator = gpa, .io = io };
    defer client.deinit();
    
    const uri = try std.Uri.parse(complete);
    var req = try client.request(.GET, uri, .{
        .extra_headers = &.{.{ .name = "Accept", .value = "text/x-flatfile" }},
    });
    defer req.deinit();

    try req.sendBodiless();

    var redirect_buffer: [1024]u8 = undefined;
    var response = try req.receiveHead(&redirect_buffer);

    const body = try response.reader(&.{}).allocRemaining(gpa, .unlimited);
    defer gpa.free(body);

    print("\n{s}\n", .{body});
}

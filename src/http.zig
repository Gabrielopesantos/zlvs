const std = @import("std");

const SP = " ";
const CRLF = "\r\n";
const NUM_TOKENS_REQUEST = 3;

const http_method = enum { GET, HEAD, INVALID };

pub const request = struct {
    method: http_method = http_method.INVALID,
    path: []const u8 = undefined,
    http_version: []const u8 = undefined,

    pub fn parse_request(self: *@This(), line: []const u8) !void {
        _ = self;
        var tokens: [NUM_TOKENS_REQUEST][]const u8 = undefined;
        var curr_token: u8 = 0;
        var line_pos: u32 = 0;
        _ = line_pos;

        while (curr_token != NUM_TOKENS_REQUEST) : (curr_token += 1) {
            for (line, 0..) |char, index| {
                switch (char) {
                    SP => {
                        tokens[curr_token] = line[0..index];
                    },
                    '\r' => {
                        break;
                    },
                    else => {
                        continue;
                    },
                }
            }

            std.debug.print("Parsing request\n", .{});
            std.debug.print("Line: {s}\n", .{line});
        }
    }
};

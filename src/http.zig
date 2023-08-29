const std = @import("std");

const SP = " ";
const CRLF = "\r\n";
const NUM_TOKENS_REQUEST = 3;

const HttpMethod = enum {
    INVALID,
    GET,
    HEAD,

    fn strToEnum(method: []const u8) @This() {
        if (std.mem.eql(u8, method, "GET")) return .GET;
        if (std.mem.eql(u8, method, "HEAD")) return .HEAD;

        return .INVALID;
    }
};

const ParseError = error{InvalidMessageFormat};

pub const request = struct {
    method: HttpMethod = HttpMethod.INVALID,
    path: []const u8 = undefined,
    http_version: []const u8 = undefined,

    pub fn parse_request(self: *@This(), line: []const u8) !void {
        var components = std.mem.tokenize(u8, line, CRLF);
        var req_line = components.next() orelse return ParseError.InvalidMessageFormat;
        var tokens = std.mem.tokenize(u8, req_line, SP);

        self.method = HttpMethod.strToEnum(tokens.next() orelse return ParseError.InvalidMessageFormat);
        self.path = tokens.next() orelse return ParseError.InvalidMessageFormat;
        self.http_version = tokens.next() orelse return ParseError.InvalidMessageFormat;
    }
};

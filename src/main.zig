const std = @import("std");
const os = std.os;

const logger = std.log.scoped(.zlvs_main);
const http = @import("http.zig");
const util = @import("util.zig");

var log_level: std.log.Level = .info;

fn handle_connection(socket_fd: os.socket_t, allocator: std.mem.Allocator) void {
    defer os.closeSocket(socket_fd);
    const msg_buf = allocator.alloc(u8, 256) catch |err| switch (err) {
        else => {
            logger.err("Could not allocate buffer: {}\n", .{err});
            return;
        },
    };
    defer allocator.free(msg_buf);

    var bytes_read = os.read(socket_fd, msg_buf);
    if (bytes_read) |value| {
        logger.debug("Successfuly read {d} bytes", .{value});
        logger.debug("Message: '{s}'", .{msg_buf[0..value]});
    } else |err| {
        logger.err("Error reading from socket: {}", .{err});
        return;
    }

    var req = http.Request{};
    req.parse_request(msg_buf) catch |err| {
        logger.debug("Failed to parse incoming request: {}", .{err});
        return;
    };

    logger.info("{s} | Method: {s} | Path: {s}", .{ req.http_version, @tagName(req.method), req.path });

    _ = util.get_path_file_type(req.path) catch |err| {
        logger.debug("Failed to file type for the path provided: {}", .{err});
        return;
    };

    var resp = http.Response{};
    resp.prepare_response(&req) catch |err| {
        logger.debug("Failed to prepare response: {}", .{err});
        return;
    };
    var resp_buf = resp.to_buf() catch |err| {
        logger.debug("Failed to prepare response: {}", .{err});
        return;
    };

    if (os.send(socket_fd, resp_buf, 0)) |bytes_sent| {
        logger.debug("Sent {d} bytes", .{bytes_sent});
        // while bytes_sent < msg.len { keep sending
    } else |err| {
        logger.err("Error sending data: {}", .{err});
    }
}

fn srv_listen(srv_sockaddr: *std.net.Address) !os.socket_t {
    // NOTE: socket_type
    const socket = try os.socket(os.linux.AF.INET, os.linux.SOCK.STREAM, 0);

    try os.bind(socket, &srv_sockaddr.any, srv_sockaddr.getOsSockLen());

    try os.listen(socket, 12); // 12?
    logger.info("Server listening on address: 127.0.0.1:{d}", .{srv_sockaddr.in.getPort()});

    return socket;
}

pub fn main() !void {
    if (std.mem.eql(u8, os.getenv("DEBUG") orelse "", "1")) log_level = .debug;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 2) return logger.warn("Invalid number of paramenters, {d}, passed.\nExpected usage: zlvs PORT.", .{args.len});

    const port = try std.fmt.parseInt(u16, args[1], 10);

    var sockaddr = std.net.Address.initIp4([4]u8{ 127, 0, 0, 1 }, port);
    var socket = try srv_listen(&sockaddr);
    defer os.closeSocket(socket);

    var sockaddr_size = sockaddr.getOsSockLen();

    // Init thread pool
    var thread_pool: std.Thread.Pool = undefined;
    try thread_pool.init(.{ .allocator = allocator, .n_jobs = 4 });
    defer thread_pool.deinit();

    while (true) {
        const conn_socket = try os.accept(socket, &sockaddr.any, &sockaddr_size, os.linux.SOCK.NONBLOCK);
        _ = try thread_pool.spawn(handle_connection, .{ conn_socket, allocator });
    }
}

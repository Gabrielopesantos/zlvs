const std = @import("std");
const os = std.os;

const logger = std.log.scoped(.zlvs_main);

var log_level: std.log.Level = .info;

fn read_connection_sock_msg(socket_fd: os.socket_t, allocator: std.mem.Allocator) void {
    defer os.closeSocket(socket_fd);
    var msg_buf = allocator.alloc(u8, 256) catch |err| switch (err) {
        else => {
            std.debug.print("Could not allocate buffer: {}\n", .{err});
            return;
        },
    };
    defer allocator.free(msg_buf);

    var bytes_read = os.read(socket_fd, msg_buf);
    if (bytes_read) |value| {
        logger.debug("Successfuly read {d} bytes", .{value});
        logger.debug("Message: '{s}'", .{msg_buf[0..value]});
    } else |err| switch (err) {
        else => std.debug.print("Got an error: {}\n", .{err}),
    }
}

fn srv_listen(srv_sockaddr: *std.net.Address) !std.os.socket_t {
    // NOTE: socket_type
    const socket = try os.socket(os.linux.AF.INET, os.linux.SOCK.STREAM, 0);

    try os.bind(socket, &srv_sockaddr.any, srv_sockaddr.getOsSockLen());

    try os.listen(socket, 12); // 12?
    logger.info("Server listening on address: 127.0.0.1:{d}", .{srv_sockaddr.in.getPort()});

    return socket;
}

pub fn main() !void {
    if (std.mem.eql(u8, std.os.getenv("DEBUG") orelse "", "1")) log_level = .debug;

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
        _ = try thread_pool.spawn(read_connection_sock_msg, .{ conn_socket, allocator });
    }
}

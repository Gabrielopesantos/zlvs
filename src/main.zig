const std = @import("std");
const os = std.os;

const logger = std.log.scoped(.zlvs_main);

var log_level: std.log.Level = .info;

fn read_connection_sock_msg(socket_fd: os.socket_t, allocator: std.mem.Allocator) void {
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

pub fn main() !void {
    if (std.mem.eql(u8, std.os.getenv("DEBUG") orelse "", "1")) log_level = .debug;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var address = std.net.Address.initIp4([4]u8{ 127, 0, 0, 1 }, 8080);

    // NOTE: socket_type
    const socket = try os.socket(os.linux.AF.INET, os.linux.SOCK.STREAM, 0);
    defer os.closeSocket(socket);

    try os.bind(socket, &address.any, address.getOsSockLen());

    try os.listen(socket, 12);
    logger.info("Server listening on address: 127.0.0.1:{s}", .{"8080"});

    var socket_len = address.getOsSockLen();
    const conn_socket = try os.accept(socket, &address.any, &socket_len, os.linux.SOCK.NONBLOCK);

    // Init thread pool
    var thread_pool: std.Thread.Pool = undefined;
    try thread_pool.init(.{ .allocator = allocator, .n_jobs = 4 });
    defer thread_pool.deinit();

    _ = try thread_pool.spawn(read_connection_sock_msg, .{ conn_socket, allocator });
}

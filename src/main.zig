const std = @import("std");
const os = std.os;

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);

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
        std.debug.print("Successfuly read {d} bytes\n", .{value});
        std.debug.print("Message: '{s}'\n", .{msg_buf[0..value]});
    } else |err| switch (err) {
        else => std.debug.print("Got an error: {}\n", .{err}),
    }
}

pub fn main() !void {
    defer arena.deinit();

    var address = std.net.Address.initIp4([4]u8{ 127, 0, 0, 1 }, 8080);

    // NOTE: socket_type
    const socket = try os.socket(os.linux.AF.INET, os.linux.SOCK.STREAM, 0);
    defer os.closeSocket(socket);

    try os.bind(socket, &address.any, address.getOsSockLen());

    try os.listen(socket, 12);

    var socket_len = address.getOsSockLen();
    const conn_socket = try os.accept(socket, &address.any, &socket_len, os.linux.SOCK.NONBLOCK);

    var thread_pool_allocator = arena.allocator();

    // Init thread pool
    var thread_pool: std.Thread.Pool = undefined;
    try thread_pool.init(.{ .allocator = thread_pool_allocator, .n_jobs = 4 });
    defer thread_pool.deinit();

    var allocator = arena.allocator();
    _ = try thread_pool.spawn(read_connection_sock_msg, .{ conn_socket, allocator });
}

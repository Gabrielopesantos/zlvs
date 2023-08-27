const std = @import("std");
const os = std.os;

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);

pub fn main() !void {
    defer arena.deinit();

    var allocator = arena.allocator();

    var address = std.net.Address.initIp4([4]u8{ 127, 0, 0, 1 }, 8080);

    // NOTE: socket_type
    const socket = try os.socket(os.linux.AF.INET, os.linux.SOCK.STREAM, 0);
    defer os.closeSocket(socket);

    try os.bind(socket, &address.any, address.getOsSockLen());

    try os.listen(socket, 12);

    var socket_len = address.getOsSockLen();
    const conn_socket = try os.accept(socket, &address.any, &socket_len, os.linux.SOCK.NONBLOCK);

    var msg_buf = try allocator.alloc(u8, 256);
    var bytes_read = os.read(conn_socket, msg_buf);
    if (bytes_read) |value| {
        std.debug.print("Successfuly read {d} bytes\n", .{value});
        std.debug.print("Message: '{s}'\n", .{msg_buf[0..value]});
    } else |err| switch (err) {
        else => std.debug.print("Got an error: {}\n", .{err}),
    }
}

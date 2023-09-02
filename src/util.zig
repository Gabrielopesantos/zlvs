const std = @import("std");
const os = std.os;
const fs = std.fs;

const MAX_PATH_SIZE = 512;

const FileType = enum {
    REGULAR,
    DIRECTORY,
    INVALID,
};

pub fn get_path_file_type(path: []const u8) !FileType {
    var null_term_path: [MAX_PATH_SIZE]u8 = undefined;
    @memcpy(null_term_path[0..path.len], path);
    null_term_path[path.len] = 0;
    var stat: os.Stat = undefined;
    _ = os.linux.stat(null_term_path[0..path.len :0], &stat);

    return FileType.INVALID;
}

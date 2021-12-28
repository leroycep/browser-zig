const std = @import("std");

pub extern fn console_log_write(ptr: [*]const u8, len: usize) void;
pub extern fn console_log_flush() void;

pub const Console = struct {
    pub fn write(_: Console, bytes: []const u8) WriteError!usize {
        console_log_write(bytes.ptr, bytes.len);
        return bytes.len;
    }

    const WriteError = error{};

    pub const Writer = std.io.Writer(Console, WriteError, write);

    pub fn writer() Writer {
        return .{ .context = Console{} };
    }
};


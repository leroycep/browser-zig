const std = @import("std");

pub const ReadableStream = opaque {
    const ReadData = struct {
        frame: anyframe,
        done: bool,
        bytesRead: usize,

        fn resumeRead(userdata: *anyopaque, done: bool, bytesRead: usize) callconv(.C) void {
            const this = @ptrCast(*@This(), @alignCast(4, userdata));
            this.done = done;
            this.bytesRead = bytesRead;
            resume this.frame;
        }
    };

    pub extern fn readable_stream_read(*@This(), bufPtr: [*]u8, bufLen: usize, callback: fn (*anyopaque, bool, usize) callconv(.C) void, userdata: *anyopaque) void;
    pub fn read(this: *@This(), buf: []u8) !usize {
        var read_data = ReadData{
            .frame = @frame(),
            .done = false,
            .bytesRead = 0,
        };
        suspend {
            readable_stream_read(this, buf.ptr, buf.len, ReadData.resumeRead, &read_data);
        }
        return read_data.bytesRead;
    }

    pub fn readAll(this: *@This(), buf: []u8) ![]u8 {
        var read_data = ReadData{
            .frame = @frame(),
            .done = false,
            .bytesRead = 0,
        };
        var buf_left = buf[0..];
        var total_bytes_read: usize = 0;
        while (!read_data.done) {
            if (buf_left.len == 0) return error.OutOfMemory;
            suspend {
                readable_stream_read(this, buf_left.ptr, buf_left.len, ReadData.resumeRead, &read_data);
            }
            total_bytes_read += read_data.bytesRead;
            std.debug.assert(read_data.bytesRead <= buf_left.len);
            buf_left = buf_left[read_data.bytesRead..];
        }
        return buf[0..total_bytes_read];
    }
};

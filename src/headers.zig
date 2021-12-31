const handle_free = @import("./main.zig").handle.handle_free;

pub const Headers = opaque {
    pub extern fn headers_get(headers: *Headers, headerNamePtr: [*]const u8, headerNameLen: usize, bufPtr: [*]u8, bufLen: usize) isize;

    pub fn free(this: *@This()) void {
        handle_free(this);
    }

    pub fn get(this: *@This(), headerName: []const u8, buf: []u8) !?[]u8 {
        const len = this.headers_get(headerName.ptr, headerName.len, buf.ptr, buf.len);
        if (len == 0) {
            return null;
        } else if (len < 0) {
            return error.OutOfMemory;
        }
        return buf[0..@intCast(usize, len)];
    }
};

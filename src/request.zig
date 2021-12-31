const Headers = @import("./main.zig").Headers;
const ReadableStream = @import("./main.zig").ReadableStream;
const handle_free = @import("./main.zig").handle.handle_free;
const handle_clone = @import("./main.zig").handle.handle_clone;

pub const Request = opaque {
    pub extern fn request_method(*@This()) u32;
    pub extern fn request_url(*@This(), bufPtr: [*]u8, bufLen: usize) isize;
    pub extern fn request_referrer(*@This(), bufPtr: [*]u8, bufLen: usize) isize;
    pub extern fn request_headers(*@This()) *Headers;
    pub extern fn request_body_open(*@This()) *ReadableStream;

    pub const Method = enum(u32) {
        get = 1,
        post = 2,
    };

    pub fn free(this: *@This()) void {
        handle_free(this);
    }

    pub fn method(this: *@This()) Method {
        return @intToEnum(Method, request_method(this));
    }

    pub fn url(this: *@This(), buf: []u8) ![]u8 {
        const len = request_url(this, buf.ptr, buf.len);
        if (len < 0) {
            return error.OutOfMemory;
        }
        return buf[0..@intCast(usize, len)];
    }

    pub fn referrer(this: *@This(), buf: []u8) !?[]u8 {
        const len = this.request_referrer(buf.ptr, buf.len);
        if (len == 0) {
            return null;
        } else if (len < 0) {
            return error.OutOfMemory;
        }
        return buf[0..@intCast(usize, len)];
    }

    pub fn headers(this: *@This()) *Headers {
        return this.request_headers();
    }

    pub fn body(this: *@This()) *ReadableStream {
        return request_body_open(this);
    }

    pub fn clone(this: *@This()) *@This() {
        return @ptrCast(*@This(), handle_clone(this));
    }
};

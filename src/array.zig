pub const Array = opaque {
    pub extern fn array_new() *@This();
    pub extern fn array_push_str(*@This(), ptr: [*]const u8, len: usize) void;
    pub extern fn array_free(*@This()) void;

    pub fn new() *@This() {
        return array_new();
    }

    pub fn pushStr(this: *@This(), str: []const u8) void {
        this.array_push_str(str.ptr, str.len);
    }

    pub fn free(this: *@This()) void {
        this.array_free();
    }
};

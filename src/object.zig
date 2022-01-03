pub const Object = opaque {
    pub extern fn object_new() *@This();
    pub extern fn object_free(*@This()) void;

    pub extern fn object_set_str(*@This(), namePtr: [*]const u8, nameLen: usize, ptr: [*]const u8, len: usize) void;
    pub extern fn object_set_bool(*@This(), namePtr: [*]const u8, nameLen: usize, value: bool) void;
    pub extern fn object_set_uint32(*@This(), namePtr: [*]const u8, nameLen: usize, value: u32) void;
    pub extern fn object_set_object(*@This(), namePtr: [*]const u8, nameLen: usize, obj: *Object) void;
    pub extern fn object_set_json(*@This(), namePtr: [*]const u8, nameLen: usize, jsonPtr: [*]const u8, jsonLen: usize) void;

    pub extern fn object_get_bool(*@This(), namePtr: [*]const u8, nameLen: usize) bool;
    pub extern fn object_get_str(*@This(), namePtr: [*]const u8, nameLen: usize, bufPtr: [*]u8, bufLen: usize) isize;
    pub extern fn object_get_object(*@This(), namePtr: [*]const u8, nameLen: usize) *Object;

    pub extern fn object_as_i64(*@This()) i64;
    pub extern fn object_as_str(*@This(), bufPtr: [*]u8, bufLen: usize) isize;
    pub extern fn object_as_json(*@This(), bufPtr: [*]u8, bufLen: usize) isize;

    pub fn new() *@This() {
        return object_new();
    }

    pub fn free(this: *@This()) void {
        this.object_free();
    }

    pub fn setStr(this: *@This(), name: []const u8, str: []const u8) void {
        this.object_set_str(name.ptr, name.len, str.ptr, str.len);
    }

    pub fn setBool(this: *@This(), name: []const u8, value: bool) void {
        this.object_set_bool(name.ptr, name.len, value);
    }

    pub fn setUint32(this: *@This(), name: []const u8, value: u32) void {
        this.object_set_uint32(name.ptr, name.len, value);
    }

    pub fn setObject(this: *@This(), name: []const u8, object: *Object) void {
        this.object_set_object(name.ptr, name.len, object);
    }

    pub fn setJSON(this: *@This(), name: []const u8, json: []const u8) void {
        this.object_set_json(name.ptr, name.len, json.ptr, json.len);
    }

    pub fn getStr(this: *@This(), name: []const u8, buf: []u8) ![]u8 {
        const len = this.object_get_str(name.ptr, name.len, buf.ptr, buf.len);
        if (len < 0) return error.OutOfMemory;
        return buf[0..@intCast(usize, len)];
    }

    pub fn asInt64(this: *@This()) i64 {
        return this.object_as_i64();
    }

    pub fn asStr(this: *@This(), buf: []u8) ![]u8 {
        const len = this.object_as_str(buf.ptr, buf.len);
        if (len < 0) return error.OutOfMemory;
        return buf[0..@intCast(usize, len)];
    }

    pub fn asJSON(this: *@This(), buf: []u8) ![]u8 {
        const len = this.object_as_json(buf.ptr, buf.len);
        if (len < 0) return error.OutOfMemory;
        return buf[0..@intCast(usize, len)];
    }

    pub fn getObject(this: *@This(), name: []const u8) ?*Object {
        return this.object_get_object(name.ptr, name.len);
    }
};

pub const Blob = opaque {
    pub extern fn blob_new(mimeTypePtr: [*]const u8, mimeTypeLen: usize, bodyPtr: [*]const u8, bodyLen: usize) *@This();
    pub extern fn blob_free(*@This()) void;

    pub fn new(mimeType: []const u8, body: []const u8) *@This() {
        return blob_new(mimeType.ptr, mimeType.len, body.ptr, body.len);
    }

    pub fn free(this: *@This()) void {
        blob_free(this);
    }
};

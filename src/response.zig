const Blob = @import("./main.zig").Blob;
const Object = @import("./main.zig").Object;

pub const Response = opaque {
    pub extern fn response_new(blob: ?*Blob, init: ?*Object) *@This();
    pub extern fn response_free(*@This()) void;

    pub const Status = enum(u32) {
        OK = 200,
        SeeOther = 303,
        NotFound = 404,
    };

    pub const Header = struct {
        name: []const u8,
        value: []const u8,
    };

    pub const InitOptions = struct {
        status: Status = .OK,
        headers: []const [2][]const u8 = &.{},
    };

    pub fn new(blob: ?*Blob, init: InitOptions) *@This() {
        var headersObj = Object.new();
        defer headersObj.free();
        for (init.headers) |header| {
            headersObj.setStr(header[0], header[1]);
        }

        var obj = Object.new();
        defer headersObj.free();
        obj.setUint32("status", @enumToInt(init.status));
        obj.setObject("headers", headersObj);

        return response_new(blob, obj);
    }

    pub fn free(this: *@This()) void {
        this.response_free();
    }
};

pub const Console = @import("./console.zig").Console;
pub const Blob = @import("./blob.zig").Blob;
pub const Event = @import("./event.zig").Event;
pub const handle = @import("./handle.zig");
pub const PromiseRaw = @import("./promise.zig").PromiseRaw;
pub const Headers = @import("./headers.zig").Headers;
pub const ReadableStream = @import("./readable_stream.zig").ReadableStream;
pub const Request = @import("./request.zig").Request;
pub const Response = @import("./response.zig").Response;
pub const Object = @import("./object.zig").Object;
pub const Array = @import("./array.zig").Array;
pub const IndexedDB = @import("./indexeddb.zig").IndexedDB;
pub const Date = @import("./date.zig").Date;
pub const Math = @import("./math.zig").Math;

pub extern fn set_timeout(callback: fn () callconv(.C) void, duration: f64) void;

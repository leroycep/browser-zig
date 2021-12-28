const Console = @import("./console.zig").Console;
const Blob = @import("./blob.zig").Blob;
const Event = @import("./event.zig").Event;
const handle = @import("./handle.zig");
const PromiseRaw = @import("./promise.zig").PromiseRaw;
const ReadableStream = @import("./readable_stream.zig").ReadableStream;
const Request = @import("./request.zig").Request;
const Response = @import("./response.zig").Response;
const Object = @import("./object.zig").Object;
const Array = @import("./array.zig").Array;
const IndexedDB = @import("./indexeddb.zig").IndexedDB;

pub extern fn set_timeout(callback: fn () callconv(.C) void, duration: f64) void;

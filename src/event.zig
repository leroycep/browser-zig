const Response = @import("./main.zig").Response;
const Request = @import("./main.zig").Request;
const PromiseRaw = @import("./main.zig").PromiseRaw;

pub const Event = opaque {
    pub const Install = opaque {};
    pub const Activate = opaque {};

    pub const Fetch = opaque {
        pub extern fn event_fetch_request(*@This()) *Request;
        pub fn request(this: *@This()) *Request {
            return event_fetch_request(this);
        }

        pub const PromiseOrValue = extern union {
            promise: *PromiseRaw,
            value: *Response,
        };

        pub extern fn event_fetch_respond_with(*@This(), *PromiseRaw) void;
        pub fn respondWith(this: *@This(), promise: *PromiseRaw) void {
            event_fetch_respond_with(this, promise);
        }
    };

    pub const Message = opaque {};

    pub const Sync = opaque {};
};

const Allocator = @import("std").mem.Allocator;
const handle_free = @import("./main.zig").handle.handle_free;

pub const PromiseRaw = opaque {
    pub extern fn promise_new(ExecuteFn, CleanupFn, userdata: ?*anyopaque) *@This();
    pub extern fn promise_resolve_void(*@This()) void;
    pub extern fn promise_resolve_any(*@This(), *anyopaque) void;
    pub extern fn promise_reject(*@This(), reasonPtr: [*]const u8, reasonLen: usize) void;

    pub fn free(this: *@This()) void {
        handle_free(this);
    }

    pub const ExecuteFn = fn (userdata: ?*anyopaque, *Resolver) callconv(.C) void;
    pub const CleanupFn = fn (userdata: ?*anyopaque) callconv(.C) void;

    /// The resolver will be cleaned up when a resolve function is called
    pub const Resolver = opaque {
        pub extern fn promise_resolver_resolve_void(*@This()) void;
        pub extern fn promise_resolver_resolve_any(*@This(), *anyopaque) void;
        pub extern fn promise_resolver_reject(*@This(), reasonPtr: [*]const u8, reasonLen: usize) void;

        pub fn resolveVoid(this: *@This()) void {
            this.promise_resolver_resolve_void();
        }

        pub fn resolveAnyHandle(this: *@This(), any: *anyopaque) void {
            this.promise_resolver_resolve_any(any);
        }

        pub fn reject(this: *@This(), reason: []const u8) void {
            this.promise_resolver_reject(reason.ptr, reason.len);
        }
    };

    pub fn new(allocator: Allocator, comptime executorFn: anytype, executorArgs: anytype) !*@This() {
        const ThisWrapper = ExecutorWrapper(executorFn, @TypeOf(executorArgs));

        const executor = try allocator.create(ThisWrapper);
        errdefer allocator.destroy(executor);

        executor.* = .{
            .allocator = allocator,
            .args = executorArgs,
            .frame = undefined,
        };

        return promise_new(ThisWrapper.execute, ThisWrapper.cleanup, executor);
    }

    fn ExecutorWrapper(comptime executorFn: anytype, ExecutorArgs: type) type {
        return struct {
            /// The Allocator that was used to allocate this ExecutorWrapper
            allocator: Allocator,

            /// The async frame of the function call. We allocate the frame during
            /// Promise.new so that the user can handle allocation failures.
            frame: @Frame(runExecutor),

            /// The arguments for the function call
            args: ExecutorArgs,

            /// This function is passed to the JavaScript runtime and then called when
            /// the Promise is finished to clean up the ExecutorWrapper.
            fn cleanup(userdata: ?*anyopaque) callconv(.C) void {
                const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), userdata.?));
                this.allocator.destroy(this);
            }

            /// This function is passed to the JavaScript runtime and then called when
            /// the JavaScript runtime determines that promise should be called. It
            /// runs the executor function.
            fn execute(userdata: ?*anyopaque, resolver: *Resolver) callconv(.C) void {
                const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), userdata.?));

                this.frame = async runExecutor(this, resolver);
            }

            // This function wraps the outer function call and transforms the result
            // into a call to `Promise.Resolver.resolve` (or `Promise.Resolver.reject`)
            fn runExecutor(this: *@This(), resolver: *Resolver) void {
                // TODO: make API to check if pointer is a web handle
                switch (@typeInfo(@typeInfo(@TypeOf(executorFn)).Fn.return_type.?)) {
                    .Void => {
                        @call(.{}, executorFn, this.args);
                        resolver.resolveVoid();
                    },
                    .Pointer => {
                        const result = @call(.{}, executorFn, this.args) catch |err| {
                            resolver.reject(@errorName(err));
                            return;
                        };
                        resolver.resolveAnyHandle(result);
                    },
                    .ErrorUnion => |eu| switch (@typeInfo(eu.payload)) {
                        .Pointer => {
                            const result = @call(.{}, executorFn, this.args) catch |err| {
                                resolver.reject(@errorName(err));
                                return;
                            };
                            resolver.resolveAnyHandle(result);
                        },
                        else => |t| @compileError("unsupported promise return type " ++ @typeName(t)),
                    },
                    else => |t| @compileError("unsupported promise return type " ++ @typeName(t)),
                }
            }
        };
    }
};

fn Promise(comptime Result: type) type {
    _ = Result;
    @compileError("TODO: unimplemented. Use this to create typed promises");
}

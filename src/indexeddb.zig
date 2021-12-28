const std = @import("std");
const Object = @import("./main.zig").Object;
const Array = @import("./main.zig").Array;
const handle_free = @import("./main.zig").handle.handle_free;

pub const IndexedDB = opaque {
    pub extern "indexeddb" fn indexeddb_open(namePtr: [*]const u8, nameLen: usize, version: u32, callbacks: *const OpenCallbacks, userdata: ?*anyopaque) void;
    pub extern "indexeddb" fn indexeddb_close(*@This()) void;
    pub extern "indexeddb" fn create_object_store(this: *@This(), namePtr: [*]const u8, nameLen: usize, options: *const ObjectStoreOptionsPacked) *ObjectStore;
    pub extern "indexeddb" fn indexeddb_transaction(this: *@This(), storeNAmes: *Array, mode: *const Transaction.Options) *Transaction;

    pub const OpenError = error{
        Blocked,
    };

    const OpenCallbacks = packed struct {
        onsuccess: fn (userdata: *anyopaque, db: *IndexedDB) callconv(.C) void,
        onupgradeneeded: fn (userdata: *anyopaque, db: *IndexedDB, oldversion: u32) callconv(.C) void,
        onerror: ?fn (userdata: *anyopaque, errcode: u32) callconv(.C) void = null,
        onblocked: ?fn (userdata: *anyopaque) callconv(.C) void = null,
    };

    pub const UpgradeFn = fn (context: ?*anyopaque, db: *IndexedDB, oldversion: u32) void;

    const OpenDBData = struct {
        frame: anyframe,
        result: OpenError!*IndexedDB,
        userUpgradeFn: UpgradeFn,
        userUpgradeData: ?*anyopaque,

        fn success(userdata: *anyopaque, db: *IndexedDB) callconv(.C) void {
            const this = @ptrCast(*@This(), @alignCast(4, userdata));

            this.result = db;
            resume this.frame;
        }

        fn err(userdata: *anyopaque, errcode: u32) callconv(.C) void {
            const this = @ptrCast(*@This(), @alignCast(4, userdata));
            // TODO: Convert error into error set member
            _ = this;
            _ = errcode;
            unreachable;
        }

        fn blocked(userdata: *anyopaque) callconv(.C) void {
            const this = @ptrCast(*@This(), @alignCast(4, userdata));
            // TODO: Convert error into error set member
            this.result = error.Blocked;
            resume this.frame;
        }

        fn upgrade(userdata: *anyopaque, db: *IndexedDB, oldversion: u32) callconv(.C) void {
            const this = @ptrCast(*@This(), @alignCast(4, userdata));
            this.userUpgradeFn(this.userUpgradeData, db, oldversion);
        }
    };

    pub fn open(name: []const u8, version: u32, upgrade: UpgradeFn, userdata: ?*anyopaque) !*IndexedDB {
        const callbacks = OpenCallbacks{
            .onsuccess = OpenDBData.success,
            .onupgradeneeded = OpenDBData.upgrade,
            .onerror = OpenDBData.err,
            .onblocked = OpenDBData.blocked,
        };
        var open_data = OpenDBData{
            .frame = @frame(),
            .result = undefined,
            .userUpgradeFn = upgrade,
            .userUpgradeData = userdata,
        };
        suspend {
            indexeddb_open(name.ptr, name.len, version, &callbacks, &open_data);
        }
        return open_data.result;
    }

    pub fn close(this: *@This()) void {
        this.indexeddb_close();
        handle_free(this);
    }

    pub const ObjectStoreOptions = struct {
        keyPath: ?[]const u8 = null,
        autoIncrement: bool = false,
    };

    pub const ObjectStoreOptionsPacked = packed struct {
        keyPathPtr: ?[*]const u8,
        keyPathLen: usize,
        autoIncrement: u32,
    };

    pub const CreateObjectStoreError = error{
        InvalidState,
        TransactionInactive,
        Constraint,
        InvalidAccess,
    };

    pub fn createObjectStore(this: *@This(), name: []const u8, options: ObjectStoreOptions) CreateObjectStoreError!*ObjectStore {
        const options_packed = ObjectStoreOptionsPacked{
            .keyPathPtr = if (options.keyPath) |k| k.ptr else null,
            .keyPathLen = if (options.keyPath) |k| k.len else @as(usize, 0),
            .autoIncrement = @boolToInt(options.autoIncrement),
        };
        return this.create_object_store(name.ptr, name.len, &options_packed);
    }

    pub fn transaction(this: *@This(), storeNames: []const []const u8, options: Transaction.Options) *Transaction {
        const store_names_array = Array.new();
        defer store_names_array.free();
        for (storeNames) |store_name| {
            store_names_array.pushStr(store_name);
        }
        return this.indexeddb_transaction(store_names_array, &options);
    }

    pub const ObjectStore = opaque {
        pub extern "indexeddb" fn object_store_add(this: *@This(), value: *Object) void;
        pub extern "indexeddb" fn object_store_add_json(this: *@This(), valJSONPtr: [*]const u8, valJSONLen: usize) void;
        pub extern "indexeddb" fn object_store_put(this: *@This(), value: *Object) void;
        pub extern "indexeddb" fn object_store_get_json(this: *@This(), GetJSONSuccessFn, GetJSONErrorFn, userdata: ?*anyopaque, key: [*]const u8, usize, val: [*]u8, usize) void;
        pub extern "indexeddb" fn object_store_open_cursor(this: *@This(), fn (?*anyopaque, ?*Object, ?*Cursor.Handle) callconv(.C) void, *anyopaque) void;

        pub const GetJSONSuccessFn = fn (userdata: ?*anyopaque, bytesWritten: usize) callconv(.C) void;
        pub const GetJSONErrorFn = fn (userdata: ?*anyopaque, errcode: u32) callconv(.C) void;

        pub fn add(this: *@This(), value: *Object) void {
            return this.object_store_add(value);
        }

        pub fn addJSON(this: *@This(), valJSON: []const u8) void {
            return this.object_store_add_json(valJSON.ptr, valJSON.len);
        }

        pub fn put(this: *@This(), value: *Object) void {
            return this.object_store_add_json(value);
        }

        const GetJSONData = struct {
            frame: anyframe,
            returnedData: union(enum) {
                uninit: void,
                success: struct { bytesWritten: usize },
                failure: struct { errcode: u32 },
            },

            fn onsuccess(userdata: ?*anyopaque, bytesWritten: usize) callconv(.C) void {
                const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), userdata.?));
                this.returnedData = .{
                    .success = .{ .bytesWritten = bytesWritten },
                };
                resume this.frame;
            }

            fn onerror(userdata: ?*anyopaque, errcode: u32) callconv(.C) void {
                const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), userdata.?));
                this.returnedData = .{
                    .failure = .{ .errcode = errcode },
                };
                resume this.frame;
            }
        };

        const ERROR_OUT_OF_MEMORY = 10;
        const ERROR_TRANSACTION_INACTIVE = 11;
        const ERROR_DATA = 12;
        const ERROR_INVALID_STATE = 13;

        /// Get a JSON string with a JSON key
        pub fn getJSON(this: *@This(), keyJSON: []const u8, valJSONBuf: []u8) !?[]u8 {
            var data = GetJSONData{
                .frame = @frame(),
                .returnedData = .uninit,
            };
            suspend {
                this.object_store_get_json(
                    GetJSONData.onsuccess,
                    GetJSONData.onerror,
                    &data,
                    keyJSON.ptr,
                    keyJSON.len,
                    valJSONBuf.ptr,
                    valJSONBuf.len,
                );
            }
            switch (data.returnedData) {
                .uninit => unreachable,
                .success => |s| return valJSONBuf[0..s.bytesWritten],
                .failure => |f| switch (f.errcode) {
                    ERROR_DATA, ERROR_INVALID_STATE => return null,
                    ERROR_OUT_OF_MEMORY => return error.OutOfMemory,
                    ERROR_TRANSACTION_INACTIVE => return error.TransactionInactive,
                    else => unreachable,
                },
            }
        }

        pub fn openCursor(this: *@This(), cursor: *Cursor) void {
            cursor.* = Cursor{
                .frame = @frame(),
                .state = .uninit,
            };
            suspend {
                this.object_store_open_cursor(Cursor.success, cursor);
            }
        }
    };

    pub const Transaction = opaque {
        pub extern "indexeddb" fn transaction_free(this: *@This()) void;
        pub extern "indexeddb" fn transaction_object_store(this: *@This(), namePtr: [*]const u8, nameLen: usize) *ObjectStore;

        pub const Options = packed struct {
            mode: Mode = .readonly,
            durability: Transaction.Durability = .default,
        };

        pub const Mode = enum(u32) {
            readonly = 0b0,
            readwrite = 0b1,
        };

        pub const Durability = enum(u32) {
            default = 0,
            strict,
            relaxed,
        };

        pub fn free(this: *@This()) void {
            this.transaction_free();
        }

        pub fn objectStore(this: *@This(), name: []const u8) *ObjectStore {
            return this.transaction_object_store(name.ptr, name.len);
        }
    };

    pub const Cursor = struct {
        frame: anyframe,
        state: State,

        pub const Handle = opaque {
            pub extern "indexeddb" fn cursor_continue(this: *@This()) void;
            pub extern "indexeddb" fn cursor_get_key_u32(this: *@This()) u32;
        };

        fn success(userdata: ?*anyopaque, nextValue: ?*Object, newHandle: ?*Handle) callconv(.C) void {
            const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), userdata.?));
            std.debug.assert((nextValue != null) == (newHandle != null));

            if (nextValue) |val| {
                this.state = .{ .going = .{
                    .value = val,
                    .handle = newHandle.?,
                } };
            } else {
                this.state = .done;
            }
            resume this.frame;
        }

        const State = union(enum) {
            uninit: void,
            going: struct {
                value: *Object,
                handle: *Cursor.Handle,
            },
            done: void,
        };

        pub fn next(this: *@This()) ?*Object {
            this.frame = @frame();
            switch (this.state) {
                .uninit => unreachable,
                .going => |g| {
                    suspend {
                        g.handle.cursor_continue();
                    }
                },
                .done => {},
            }
            switch (this.state) {
                .uninit => return null,
                .going => |g| return g.value,
                .done => return null,
            }
        }

        pub fn getKeyU32(this: *@This()) u32 {
            switch (this.state) {
                .going => |g| return g.handle.cursor_get_key_u32(),
                else => unreachable,
            }
        }
    };
};

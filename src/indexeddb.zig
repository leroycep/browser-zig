const std = @import("std");
const Object = @import("./main.zig").Object;
const Array = @import("./main.zig").Array;
const handle_free = @import("./main.zig").handle.handle_free;
const jserr = @import("./errors.zig");

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

    /// [createIndex documentation][] by [Mozilla Contributors][] is licensed under [CC-BY-SA 2.5][].
    ///
    /// [createIndex documentation]: https://developer.mozilla.org/en-US/docs/Web/API/IDBObjectStore/createIndex
    /// [Mozilla Contributors]: https://developer.mozilla.org/en-US/docs/MDN/About/contributors.txt
    /// [CC-BY-SA 2.5]: https://creativecommons.org/licenses/by-sa/2.5/
    pub const CreateIndexError = error{
        /// Thrown if an index with the same name already exists in the
        /// database. Index names are case-sensitive.
        Constraint,

        /// Thrown if the provided key path is a sequence, and multiEntry
        /// is set to true in the objectParameters object.
        InvalidAccess,

        /// Thrown if:
        ///
        /// - The method was not called from a versionchange transaction mode
        ///   callback, i.e. from inside a IDBOpenDBRequest.onupgradeneeded handler.
        /// - The object store has been deleted.
        InvalidState,

        /// Thrown if the provided keyPath is not a [valid key path][].
        ///
        /// [valid key path]: https://www.w3.org/TR/IndexedDB/#dfn-valid-key-path
        Syntax,

        /// Thrown if the transaction this IDBObjectStore belongs to is not active (e.g. has been deleted or
        /// removed.) In Firefox previous to version 41, an `InvalidStateError` was raised in this case as
        /// well, which was misleading; this has now been fixed (see [bug 1176165][].)
        ///
        /// [bug 1176165]: https://bugzilla.mozilla.org/show_bug.cgi?id=1176165
        TransactionInactive,
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
        pub extern "indexeddb" fn object_store_get(this: *@This(), GetSuccessFn, GetErrorFn, userdata: ?*anyopaque, keyJSON: [*]const u8, usize) void;
        //pub extern "indexeddb" fn object_store_get_json(this: *@This(), GetJSONSuccessFn, GetJSONErrorFn, userdata: ?*anyopaque, key: [*]const u8, usize, val: [*]u8, usize) void;
        pub extern "indexeddb" fn object_store_open_cursor(this: *@This(), ?*Object, direction: u32) *Cursor.RequestHandle;
        pub extern "indexeddb" fn object_store_open_key_cursor(this: *@This(), ?*Object, direction: u32) *Cursor.RequestHandle;
        pub extern "indexeddb" fn object_store_create_index(this: *@This(), namePtr: [*]const u8, nameLen: usize, keyPathPtr: [*]const u8, keyPathLen: usize, objJSONPtr: ?[*]const u8, objJSONLen: usize) i32;
        pub extern "indexeddb" fn object_store_index(this: *@This(), namePtr: [*]const u8, nameLen: usize) ?*Index;

        pub const GetSuccessFn = fn (userdata: ?*anyopaque, object: ?*Object) callconv(.C) void;
        pub const GetErrorFn = fn (userdata: ?*anyopaque, errcode: u32) callconv(.C) void;

        pub const CreateIndexOptions = struct {
            unique: ?bool = null,
            multiEntry: ?bool = null,
            locale: ?[]const u8 = null,

            pub fn isDefault(this: @This()) bool {
                return this.unique == null and this.multiEntry == null and this.locale == null;
            }
        };

        pub fn createIndex(this: *@This(), name: []const u8, keyPath: []const u8, options: CreateIndexOptions) !*Index {
            std.log.debug("{s}:{} createIndex", .{ @src().file, @src().line });
            if (!options.isDefault()) {
                var json_buf: [100]u8 = undefined;
                var json_fbs = std.io.fixedBufferStream(&json_buf);
                std.json.stringify(
                    options,
                    .{ .emit_null_optional_fields = false },
                    json_fbs.writer(),
                ) catch |e| {
                    std.log.debug("{s}:{} {}", .{ @src().file, @src().line, e });
                    unreachable;
                };
                const json = json_fbs.getWritten();

                std.log.debug("{s}:{} json = {s}", .{ @src().file, @src().line, json });
                const handle = try jserr.errcodeMaybe(this.object_store_create_index(
                    name.ptr,
                    name.len,
                    keyPath.ptr,
                    keyPath.len,
                    json.ptr,
                    json.len,
                ));

                return @intToPtr(*Index, @intCast(u32, handle));
            } else {
                std.log.debug("{s}:{} createIndex", .{ @src().file, @src().line });
                const handle = try jserr.errcodeMaybe(this.object_store_create_index(
                    name.ptr,
                    name.len,
                    keyPath.ptr,
                    keyPath.len,
                    null,
                    0,
                ));

                std.log.debug("{s}:{} handle = {x}", .{ @src().file, @src().line, handle });
                return @intToPtr(*Index, @intCast(u32, handle));
            }
        }

        pub fn index(this: *@This(), name: []const u8) ?*Index {
            return this.object_store_index(name.ptr, name.len);
        }

        pub fn add(this: *@This(), value: *Object) void {
            return this.object_store_add(value);
        }

        pub fn addJSON(this: *@This(), valJSON: []const u8) void {
            return this.object_store_add_json(valJSON.ptr, valJSON.len);
        }

        pub fn put(this: *@This(), value: *Object) void {
            return this.object_store_put(value);
        }

        const GetData = struct {
            frame: anyframe,
            returnedData: union(enum) {
                uninit: void,
                success: struct { object: ?*Object },
                failure: struct { errcode: u32 },
            },

            fn onsuccess(userdata: ?*anyopaque, object: ?*Object) callconv(.C) void {
                const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), userdata.?));
                this.returnedData = .{
                    .success = .{ .object = object },
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

        /// Get a JSON string with a JSON key
        pub fn get(this: *@This(), keyJSON: []const u8) !?*Object {
            var data = GetData{
                .frame = @frame(),
                .returnedData = .uninit,
            };
            suspend {
                this.object_store_get(
                    GetData.onsuccess,
                    GetData.onerror,
                    &data,
                    keyJSON.ptr,
                    keyJSON.len,
                );
            }
            switch (data.returnedData) {
                .uninit => unreachable,
                .success => |s| return s.object,
                .failure => |f| switch (jserr.errcodeToError(f.errcode)) {
                    error.Data, error.InvalidState => return null,
                    error.OutOfMemory, error.TransactionInactive => |e| return e,
                    else => unreachable,
                },
            }
        }

        pub fn openCursor(this: *@This(), cursor: *Cursor, query: ?*Object, direction: Cursor.Direction) void {
            cursor.* = .{
                .frame = undefined,
                .state = .{ .uninit = this.object_store_open_cursor(query, @enumToInt(direction)) },
            };
        }

        pub fn openKeyCursor(this: *@This(), cursor: *Cursor, query: ?*Object, direction: Cursor.Direction) void {
            cursor.* = .{
                .frame = undefined,
                .state = .{ .uninit = this.object_store_open_key_cursor(query, @enumToInt(direction)) },
            };
        }
    };

    pub const Index = opaque {
        pub fn openCursor(this: *@This(), cursor: *Cursor, query: ?*Object, direction: Cursor.Direction) void {
            const obj_store = @ptrCast(*ObjectStore, this);
            const handle = obj_store.object_store_open_cursor(query, @enumToInt(direction));
            std.log.debug("handle {*}", .{handle});
            cursor.* = .{
                .frame = undefined,
                .state = .{ .uninit = handle },
            };
        }

        pub fn openKeyCursor(this: *@This(), cursor: *Cursor, query: ?*Object, direction: Cursor.Direction) void {
            const obj_store = @ptrCast(*ObjectStore, this);
            const handle = obj_store.object_store_open_key_cursor(query, @enumToInt(direction));
            cursor.* = .{
                .frame = undefined,
                .state = .{ .uninit = handle },
            };
        }
    };

    pub const Transaction = opaque {
        pub extern "indexeddb" fn transaction_abort(this: *@This()) void;
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
            handle_free(this);
        }

        pub fn abort(this: *@This()) void {
            this.transaction_abort();
        }

        pub fn objectStore(this: *@This(), name: []const u8) *ObjectStore {
            return this.transaction_object_store(name.ptr, name.len);
        }
    };

    pub const Cursor = struct {
        frame: anyframe,
        state: State,

        pub const RequestHandle = opaque {
            pub extern "indexeddb" fn cursor_request_init(this: *@This(), successCb: SuccessFn, userdata: ?*anyopaque) void;

            const SuccessFn = fn (?*anyopaque, ?*Object, ?*Object, ?*Handle) callconv(.C) void;
        };

        pub const Handle = opaque {
            pub extern "indexeddb" fn cursor_continue(this: *@This(), successCb: fn (?*anyopaque, ?*Object, ?*Object, ?*Handle) callconv(.C) void, userdata: ?*anyopaque) void;
            pub extern "indexeddb" fn cursor_get_key_u32(this: *@This()) u32;
        };

        pub const KeyRange = opaque {
            pub fn asObject(this: *@This()) *Object {
                return @ptrCast(*Object, this);
            }
        };

        pub const Direction = enum(u8) {
            next = 0,
            nextunique = 1,
            prev = 2,
            prevunique = 3,
        };

        fn success(
            userdata: ?*anyopaque,
            nextKey: ?*Object,
            nextValue: ?*Object,
            newHandle: ?*Handle,
        ) callconv(.C) void {
            const this = @ptrCast(*@This(), @alignCast(@alignOf(@This()), userdata.?));
            std.debug.assert((nextKey != null) == (newHandle != null));

            if (this.state == .going) {
                handle_free(this.state.going.handle);
            }

            if (newHandle) |new_handle| {
                this.state = .{ .going = .{
                    .handle = new_handle,
                    .key = nextKey.?,
                    .value = nextValue,
                } };
            } else {
                this.state = .done;
            }
            resume this.frame;
        }

        const State = union(enum) {
            uninit: *RequestHandle,
            going: struct {
                handle: *Cursor.Handle,
                key: *Object,
                value: ?*Object,
            },
            done: void,
        };

        const Entry = struct {
            key: *Object,
            value: ?*Object,
        };

        pub fn next(this: *@This()) ?Entry {
            this.frame = @frame();
            std.log.debug("hello, world {any}", .{this.state});
            switch (this.state) {
                .uninit => |rh| {
                    suspend {
                        rh.cursor_request_init(Cursor.success, this);
                    }
                },
                .going => |g| {
                    suspend {
                        g.handle.cursor_continue(Cursor.success, this);
                    }
                },
                .done => {},
            }
            switch (this.state) {
                .uninit => return null,
                .going => |g| return Entry{ .key = g.key, .value = g.value },
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

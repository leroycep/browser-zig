pub const UNKNOWN = 1;
pub const OUT_OF_MEMORY = 10;
pub const TRANSACTION_INACTIVE = 11;
pub const DATA = 12;
pub const INVALID_STATE = 13;
pub const CONSTRAINT = 14;
pub const INVALID_ACCESS = 15;
pub const SYNTAX = 16;

const BrowserError = error{
    Unknown,
    OutOfMemory,
    TransactionInactive,
    Data,
    InvalidState,
    Constraint,
    InvalidAccess,
    Syntax,
};

pub fn errcodeMaybe(errcode: i64) BrowserError!u63 {
    if (errcode >= 0) return @intCast(u63, errcode);
    return errcodeToError(errcode);
}

pub fn errcodeToError(errcode: i64) BrowserError {
    return switch (-errcode) {
        UNKNOWN => error.Unknown,
        OUT_OF_MEMORY => error.OutOfMemory,
        TRANSACTION_INACTIVE => error.TransactionInactive,
        DATA => error.Data,
        INVALID_STATE => error.InvalidState,
        CONSTRAINT => error.Constraint,
        INVALID_ACCESS => error.InvalidAccess,
        SYNTAX => error.Syntax,
        else => @panic("Unknown error code"),
    };
}

pub const Date = opaque {
    /// Returns the number of milliseconds since January 1, 1970 00:00:00 UTC
    pub extern fn date_now() i64;

    /// Returns the number of milliseconds since January 1, 1970 00:00:00 UTC
    pub fn now() i64 {
        return date_now();
    }
};

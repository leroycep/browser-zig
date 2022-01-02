pub const Math = opaque {
    pub extern fn math_random() f64;

    pub fn random() f64 {
        return math_random();
    }
};

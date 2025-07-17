init: Init,
init_layout_arg: InitLayoutArg,

pub const Init = enum {
    /// init() is not supported, user must explicitly call
    /// valueInit() or refInit().
    explicit,

    /// init() is the same as valueInit(). Causes a compilation
    /// error if implementation doesn't support valueInit().
    value,

    /// init() is the same as refInit()
    ref,
};

pub const InitLayoutArg = enum {
    /// .never if layout is empty, otherwise .always
    auto,

    /// Always use an explicit layout arg, even if empty
    always,

    /// Never use an explicit layout arg. Causes a compilation
    /// error if layout is non-empty.
    never,
};

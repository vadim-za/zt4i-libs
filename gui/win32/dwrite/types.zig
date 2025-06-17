pub const FONT_WEIGHT = enum(c_uint) {
    THIN = 100,
    EXTRA_LIGHT = 200,
    LIGHT = 300,
    SEMI_LIGHT = 350,
    NORMAL = 400,
    MEDIUM = 500,
    SEMI_BOLD = 600,
    BOLD = 700,
    EXTRA_BOLD = 800,
    BLACK = 900,
    EXTRA_BLACK = 950,
    _, // Valid value range 1...999

    pub const ULTRA_LIGHT = .EXTRA_LIGHT;
    pub const REGULAR = .NORMAL;
    pub const DEMI_BOLD = .SEMI_BOLD;
    pub const ULTRA_BOLD = .EXTRA_BOLD;
    pub const HEAVY = .BLACK;
    pub const ULTRA_BLACK = .EXTRA_BLACK;
};

pub const FONT_STRETCH = enum(c_uint) {
    UNDEFINED = 0,
    ULTRA_CONDENSED = 1,
    EXTRA_CONDENSED = 2,
    CONDENSED = 3,
    SEMI_CONDENSED = 4,
    NORMAL = 5,
    SEMI_EXPANDED = 6,
    EXPANDED = 7,
    EXTRA_EXPANDED = 8,
    ULTRA_EXPANDED = 9,
};

pub const FONT_STYLE = enum(c_uint) {
    NORMAL = 0,
    OBLIQUE = 1,
    ITALIC = 2,
};

pub const MEASURING_MODE = enum(c_uint) {
    NATURAL,
    CLASSIC,
    GDI_NATURAL,
};

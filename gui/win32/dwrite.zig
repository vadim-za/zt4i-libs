const factory = @import("dwrite/factory.zig");
pub const IFactory = factory.IFactory;
pub const FACTORY_TYPE = factory.FACTORY_TYPE;
pub const createFactory = factory.createFactory;

const text_format = @import("dwrite/text_format.zig");
pub const ITextFormat = text_format.ITextFormat;

const types = @import("dwrite/types.zig");
pub const FONT_WEIGHT = types.FONT_WEIGHT;
pub const FONT_STRETCH = types.FONT_STRETCH;
pub const FONT_STYLE = types.FONT_STYLE;
pub const MEASURING_MODE = types.MEASURING_MODE;

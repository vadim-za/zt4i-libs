const std = @import("std");

const common = @import("d2d1/common.zig");
pub const SIZE_U = common.SIZE_U;
pub const POINT_2F = common.POINT_2F;
pub const RECT_F = common.RECT_F;
pub const MATRIX_3X2_F = common.MATRIX_3X2_F;
pub const identityMatrix = common.identityMatrix;
pub const COLOR_F = common.COLOR_F;
pub const ALPHA_MODE = common.ALPHA_MODE;
pub const PIXEL_FORMAT = common.PIXEL_FORMAT;

const factory = @import("d2d1/factory.zig");
pub const IFactory = factory.IFactory;
pub const FACTORY_TYPE = factory.FACTORY_TYPE;
pub const FACTORY_OPTIONS = factory.FACTORY_OPTIONS;
pub const DEBUG_LEVEL = factory.DEBUG_LEVEL;
pub const createFactory = factory.createFactory;

const render_target = @import("d2d1/render_target.zig");
pub const TAG = render_target.TAG;
pub const RENDER_TARGET_TYPE = render_target.RENDER_TARGET_TYPE;
pub const RENDER_TARGET_USAGE = render_target.RENDER_TARGET_USAGE;
pub const FEATURE_LEVEL = render_target.FEATURE_LEVEL;
pub const PRESENT_OPTIONS = render_target.PRESENT_OPTIONS;
pub const RENDER_TARGET_PROPERTIES = render_target.RENDER_TARGET_PROPERTIES;
pub const HWND_RENDER_TARGET_PROPERTIES = render_target.HWND_RENDER_TARGET_PROPERTIES;
pub const WINDOW_STATE = render_target.WINDOW_STATE;
pub const IRenderTarget = render_target.IRenderTarget;
pub const IHwndRenderTarget = render_target.IHwndRenderTarget;

const resource = @import("d2d1/resource.zig");
pub const IResource = resource.IResource;

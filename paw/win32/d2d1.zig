const std = @import("std");

const brush = @import("d2d1/brush.zig");
pub const BRUSH_PROPERTIES = brush.BRUSH_PROPERTIES;
pub const IBrush = brush.IBrush;
pub const ISolidColorBrush = brush.ISolidColorBrush;

const common = @import("d2d1/common.zig");
pub const SIZE_U = common.SIZE_U;
pub const POINT_2F = common.POINT_2F;
pub const RECT_F = common.RECT_F;
pub const BEZIER_SEGMENT = common.BEZIER_SEGMENT;
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

const geometry = @import("d2d1/geometry.zig");
pub const IGeometry = geometry.IGeometry;
pub const IPathGeometry = geometry.IPathGeometry;

const geometry_sink = @import("d2d1/geometry_sink.zig");
pub const FILL_MODE = geometry_sink.FILL_MODE;
pub const PATH_SEGMENT = geometry_sink.PATH_SEGMENT;
pub const FIGURE_BEGIN = geometry_sink.FIGURE_BEGIN;
pub const FIGURE_END = geometry_sink.FIGURE_END;
pub const ISimplifiedGeometrySink = geometry_sink.ISimplifiedGeometrySink;
pub const IGeometrySink = geometry_sink.IGeometrySink;

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

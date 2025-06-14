const std = @import("std");
const os = std.os.windows;

const paw = @import("../paw.zig");

pub const Error = paw.Error;

pub fn SUCCEEDED(hr: os.HRESULT) bool {
    return hr >= 0;
}

pub fn FAILED(hr: os.HRESULT) bool {
    return hr < 0;
}

pub const IID = os.GUID;
pub const REFIID = *const IID;

// ----------------------------------------------------

pub const IUnknown = @import("com/IUnknown.zig");

pub fn queryInterface(iptr: anytype, IType: type) !?*IType {
    return iptr.as(IUnknown).queryInterface(IType);
}

pub fn getInterface(iptr: anytype, IType: type) !*IType {
    return iptr.as(IUnknown).getInterface(IType);
}

pub fn acquire(iptr: anytype) @TypeOf(iptr) {
    iptr.as(IUnknown).addRef();
    return iptr;
}

pub fn release(iptr: anytype) void {
    iptr.as(IUnknown).release();
}

pub fn cast(iptr: anytype, IType: type) *IType {
    const IPtr = @TypeOf(iptr.*);
    if (comptime !isBaseOf(IPtr, IType))
        @compileError(@typeName(IType) ++
            " is not a base of " ++ @typeName(IPtr));
    return @ptrCast(iptr);
}

fn isBaseOf(IDerived: type, IBase: type) bool {
    return IDerived == IBase or
        @hasDecl(IDerived, ".Base") and isBaseOf(IDerived.@".Base", IBase);
}

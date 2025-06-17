const std = @import("std");
const os = std.os.windows;

const com = @import("../com.zig");

pub const iid = os.GUID.parse("{00000000-0000-0000-C000-000000000046}");
const Self = @This();

vtbl: *const Vtbl,
pub const Vtbl = extern struct {
    // On PPC there's should be one extra entry here, we don't need it
    QueryInterface: *const fn (
        self: *Self,
        riid: com.REFIID,
        ppvObject: *?*anyopaque,
    ) callconv(.winapi) os.HRESULT,
    AddRef: *const fn (self: *Self) callconv(.winapi) os.ULONG,
    Release: *const fn (self: *Self) callconv(.winapi) os.ULONG,
};

pub const as = com.cast;

pub fn queryInterface(self: *@This(), IType: type) com.Error!?*IType {
    var result: ?*IType = null;

    const hr = self.vtbl.QueryInterface(
        self,
        &IType.iid,
        @ptrCast(&result),
    );

    if (com.SUCCEEDED(hr))
        return result;

    if (hr == os.E_NOINTERFACE)
        return null;

    return com.Error.OsApi;
}

pub fn getInterface(self: *@This(), IType: type) com.Error!*IType {
    var result: ?*IType = null;

    if (com.FAILED(self.vtbl.QueryInterface(
        self,
        &IType.iid,
        @ptrCast(&result),
    )))
        return com.Error.OsApi;

    return result orelse com.Error.OsApi;
}

pub fn addRef(self: *@This()) void {
    _ = self.vtbl.AddRef(self);
}

pub fn release(self: *@This()) void {
    _ = self.vtbl.Release(self);
}

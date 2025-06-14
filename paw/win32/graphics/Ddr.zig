// Device-dependent resource

const std = @import("std");
const d2d1 = @import("../d2d1.zig");

pub const Self = @This();

vtbl: *const Vtbl,
node: List.Node,

pub const CreationError = error{Failed};

pub const Vtbl = struct {
    ensureCreated: *const fn (
        self: *Self,
        target: *d2d1.IRenderTarget,
    ) CreationError!void,
    ensureReleased: *const fn (
        self: *Self,
    ) void,
};

pub fn makeVtbl(Type: type) *const Vtbl {
    return comptime &.{
        .ensureCreated = Type.ensureCreated,
        .ensureReleased = Type.ensureReleased,
    };
}

pub fn ensureCreated(
    self: *Self,
    target: *d2d1.IRenderTarget,
) CreationError!void {
    return self.vtbl.ensureCreated(self, target);
}

pub fn ensureReleased(
    self: *Self,
) void {
    return self.vtbl.ensureReleased(self);
}

const ListData = struct {};
const List = std.DoublyLinkedList(ListData);

pub const Collection = struct {
    list: List = .{},

    pub fn deinit(self: *const @This()) void {
        std.debug.assert(self.list.len == 0);
    }

    pub fn add(self: *@This(), ddr: *Self) void {
        self.list.append(&ddr.node);
    }

    pub fn remove(self: *@This(), ddr: *Self) void {
        self.list.remove(&ddr.node);
    }

    pub fn ensureAllCreated(
        self: *const @This(),
        target: *d2d1.IRenderTarget,
    ) CreationError!void {
        var node = self.list.first;
        while (node) |n| : (node = n.next) {
            const ddr: *Self = @alignCast(@fieldParentPtr("node", n));
            try ddr.ensureCreated(target);
        }
    }

    pub fn ensureAllReleased(
        self: *const @This(),
    ) void {
        var node = self.list.first;
        while (node) |n| : (node = n.next) {
            const ddr: *Self = @alignCast(@fieldParentPtr("node", n));
            ddr.ensureReleased();
        }
    }
};

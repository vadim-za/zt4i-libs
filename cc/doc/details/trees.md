# Trees

Here we are going to discuss the details specific to the tree containers.

## Node ordering

Sorted trees need to order their nodes. On a purely intuitive level, we would like to simply be able to apply `std.math.order()` to the nodes. There are however a number of problems with that:
- `std.math.order()` is restricted to numeric types and cannot be used to compare tree nodes.
- Rather than comparing nodes we need to compare their keys, or, even more commonly, we need to compare a node's key to an explicitly supplied key value.
- Usually the keys are present as explicitly stored values (in variables or in structure fields) of one and the same type. However, in more complicated situations the key can be stored in a number of different forms/types and/or locations. For that reason, the CC library's tree expects an implementation of the ordering comparison between a node and a "comparable value", whatever the latter may be.

This mentioned implementation is to be supplied as the `compare_to` field of the tree configuration parameter. There are a number of ways how the implementation can be provided and supplied.

### A node method

```
const MyNode = struct {
    // For simplicity we store key in a single field,
    // but actually it can be implicitly stored across
    // a number of different fields and structs.
    key: i32,
    hook: MyTree.Hook = .{},

    // The method needs to be pub, since it's referred to by name
    // in the tree configuation.
    pub fn compareTo(
        self: *const @This(),
        comparable_value_ptr: anytype,
    ) std.math.Order {
        return switch(@TypeOf(comparable_value_ptr.*)) {
            // Special case: in order to be able to use the
            // tree's insertNode() method, we should be able
            // to compare to another node.
            MyNode => return self.compareTo(
                comparable_value_ptr.key,
            ),
            // Otherwise we assume that the supplied value
            // is comparable with the i32 key (it is not
            // necessarily an i32 value, could be e.g. a
            // comptime_int).
            else => return std.math.order(
                self.key,
                comparable_value_ptr.*,
            ),
        };
    }
};

// Notice that one and the same configuration can be reused
// for a number of different tree/node types, since the
// 'compare_to' field just specifies a method name, but
// doesn't explicitly refer to a method of a particular type.
const MyTree = zt4i.cc.Tree(MyNode, .{
    .implementation = .avl,
    .hook_field = "hook",
    .compare_to = .method("compareTo"),
    .ownership_tracking = ......,
});
```

### A freestanding function

Instead of using a node method, we could put essentially the same functionality into a freestanding function. Some details differ. Compare the following implementation to the node method example above.
```
const MyNode = struct {
    key: i32,
    hook: MyTree.Hook = .{},
};

// The function is referred directly in the tree configuation,
// therefore it doesn't need to be pub, as long as tree
// configuration is defined in the same file.
//
// In principle we'd like 'node_ptr' to have '*const Node' or
// '*Node' type, but it seems that that is prevented by Zig
// Issue #16932. The upside is that with 'node_ptr' being
// 'anytype' this function can be reused for a number of
// different node types.
fn compareTo(
    node_ptr: anytype,
    comparable_value_ptr: anytype,
) std.math.Order {
    return switch (@TypeOf(comparable_value_ptr.*)) {
        @TypeOf(node_ptr.*) => return compareTo(
            node_ptr,
            &comparable_value_ptr.key,
        ),
        else => return std.math.order(
            node_ptr.key,
            comparable_value_ptr.*,
        ),
    };
}

// Again, one and the same configuration can be reused
// for a number of different tree/node types here.
const MyTree = zt4i.cc.Tree(MyNode, .{
    .implementation = .avl,
    .hook_field = "hook",
    .compare_to = .function(compareTo),
    .ownership_tracking = ......,
});
```

### Using a field

We could refer to a particular field of the node as the reference for the comparison:
```
const MyNode = struct {
    key: i32,
    hook: MyTree.Hook = .{},
};

// Again, one and the same configuration can be reused
// for a number of different tree/node types here.
const MyTree = zt4i.cc.Tree(MyNode, .{
    .implementation = .avl,
    .hook_field = "hook",
    // The 'default' comparson can be used if the key can
    // be compared with std.math.Order, or if the key is
    // a single-item pointer.
    .compare_to = .useField("key", .default),
    .ownership_tracking = ......,
});
```
N.B. The `useField` option also automatically covers comparison to a node, so it is compatible to `insertNode()`.

If the `default` comparison functionality doesn't fit the purpose, one can supply a "nested" `compare_to` definition:
```
const MyNode = struct {
    key: []const u8,
    hook: MyTree.Hook = .{},
};

// Again, one and the same configuration can be reused
// for a number of different tree/node types here.
const MyTree = zt4i.cc.Tree(MyNode, .{
    .implementation = .avl,
    .hook_field = "hook",
    // The 'default' comparson can be used if the key can
    // be compared with std.math.Order, or if it is a
    // single-item pointer.
    .compare_to = .useField(
        "key",
        .function(compareTo),
    ),
    .ownership_tracking = ......,
});

// We could have declared parameters as '*const []const u8`,
// but declaring them as 'anytype' allows coercion from other
// types. E.g. we are able to call 'find(&"string")', which
// results in a '*const [6:0]u8' rather than '*const []const u8`
// pointer.
fn compareTo(
    reference_value_ptr: anytype,
    comparable_value_ptr: anytype,
) std.math.Order {
    // No need to explicitly handle comparison to another node,
    // this is taken care of by useField().
    return std.mem.order(
        u8,
        reference_value_ptr.*,
        comparable_value_ptr.*,
    );
}
```

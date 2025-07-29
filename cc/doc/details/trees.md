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

    pub fn compareTo(
        self: *const @This(),
        comparable_value_ptr: anytype,
    ) std.math.Order {
        return switch(@TypeOf(comparable_value_ptr.*)) {
            // In order to be able to use the tree's
            // insertNode() method, we also should be
            // able to compare to another node
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

const MyTree = zt4i.cc.Tree(MyNode, .{
    .implementation = .avl,
    .hook_field = "hook",
    .compare_to = .method("compareTo"),
    .ownership_tracking = ......,
});
```

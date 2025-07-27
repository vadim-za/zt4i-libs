# Tree-specific APIs

- [Configuration](#configuration)

## Configuration

Since the CC library trees (currently, just the AVL trees) are binary sorted trees, they have an extra configuration parameter, not present with lists. This parameter defines the (strict) order for the tree elements and can be specified in a number of ways.

### Ordering function

The ordering function compares a tree node to... anything which may semantically represent a key value. In the simplest case it just compares to the key value itself:
```
const MyNode = struct {
    key: i32,
    hook: MyTree.Hook = .{},
};

const MyTree = zt4i.cc.Tree(MyNode, .{
    .implementation = .avl,
    .hook_field = "hook",
    .compare_to = .function(compareNodeTo),
    .ownership_tracking = .....,
});

fn compareNodeTo(
    node: *const MyNode,
    key: *const i32,
) std.math.Order {
    return std.math.order(node.key, key.*);
}
```
The function will be used in the tree lookup (the tree's `find()` method) and insertion (the tree's `insert()` method). It also can be used by the tree's `insertNode()` method, if it fulfills an extra requirement, discussed elsewhere in this documentation.

### Ordering method

If the function is not freestanding but is a method of the node, it can be specified as:
```
const MyNode = struct {
    key: i32,
    hook: MyTree.Hook = .{},

    // The method needs to be pub
    pub fn compareTo(
        self: *const @This(),
        key: *const i32,
    ) std.math.Order {
        return std.math.order(node.key, key.*);
    }
};

const MyTree = zt4i.cc.Tree(MyNode, .{
    .........
    .compare_to = .method("compareTo"),
    .........
});
```
Of course we could still do
```
    .compare_to = .function(MyNode.compareTo),
```
instead, but the latter would be only applicable to MyNode, while using the `.method("compareTo")` option makes the configuration agnostic to the node type, so that it can be reused for different node types:
```
const config = zt4i.cc.trees.Config{
    .implementation = .avl,
    .hook = "hook",
    .compare_to = .method("compareTo"),
    .ownership_tracking = ......,
};

// Each of MyNode1 and MyNode2 implements its own
// compareTo() method.
const MyTree1 = zt4i.cc.Tree(MyNode1, config);
const MyTree2 = zt4i.cc.Tree(MyNode2, config);
```

### Generic ordering methods

???

### Generic ordering functions

????

There is, however, still a way to achieve the same kind of generic applicability for functions. We need to declare the function's first parameter as `anytype`:
```
const config = zt4i.cc.trees.Config{
    .implementation = .avl,
    .hook = "hook",
    .compare_to = compareNodeTo,
    .ownership_tracking = ......,
};

fn compareNodeTo(
    node_ptr: anytype,
    key: *const i32,
) std.math.Order {
    return std.math.order(node_ptr.key, key.*);
}
```

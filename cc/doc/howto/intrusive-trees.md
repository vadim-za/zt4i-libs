# Intrusive trees quick howto

This document gives a quick howto-style introduction into intrusive trees support by the CC library. It is recommended to read the [Intrusive trees quick howto](intrusive-lists.md) first.

## Tree declaration

Define tree and node types:
```
// The node type is basically the same as for lists,
// except that it needs to define the key for the ordering.
const MyNode = struct {
    // The key can be defined as an explicitly stored value
    // (of pretty much any type) or implicitly. In the simplest
    // case the key uses an integer or single-item pointer type
    // and is explicitly stored as a field in the tree node.
    key: i32,

    field1: Type1,
    field2: Type2,

    hook: MyList.Hook = .{},
};

const MyTree = zt4i.cc.Tree(MyNode, .{
    // Currently there are only AVL trees
    .implementation = .avl,

    .hook_field = "hook",

    // Use the "key" field for comparison, using
    // the "default" comparison routine.
    .compare_to = .useField("key", .default),

    .ownership_tracking = .{
        .owned_items = .container_ptr,
        .free_items = .on,
    },
});
```

## Tree construction/destruction

The tree construction/destruction is similar to the one of the lists. The following examples demonstrate constructing a tree as a local variable (to be temporarily used inside a function). More typically, a tree would be a field of a larger struct.
```
    var tree: MyTree = .{};
    defer tree.deinit();
```
N.B. The in-place `init()` pattern available for CC lists is currently not supported by the trees.

Similarly to the lists, the tree is supposed to be empty at the time `deinit()` is called. If necessary, you must remove all nodes from the tree:
```
    var tree: MyTree = .{};
    defer {
        tree.removeAll(.{});
        tree.deinit();
    }
```
Similarly to the lists, `removeAll()` doesn't destroy the removed nodes. Removing the nodes from a (semi-)balanced tree one-by-one can be unnecessarily expensive, since the nodes would be reordered every time. Instead one can supply a discarder functor to `removeAll()`:
```
    // The following code assumes that there is an
    // 'alloc' local variable defined above, containing
    // the allocator that will be used to allocate the
    // nodes.
    var tree: MyTree = .{};
    defer {
        const discarder = struct {
            alloc: std.mem.Allocator,
            pub fn discard(
                self: *const @This(),
                node: *Node,
            ) void {
                self.alloc.destroy(node);
            }
        }{ .alloc = alloc };
        tree.removeAll(.{ .discarder = &discarder });
        tree.deinit();
    }
```
N.B. In theory there is a simpler way to define the discarder for the above case:
```
    var tree: MyTree = .{};
    defer {
        // This discarder relies on details of declaration
        // of std.mem.Allocator.destroy(). In particular,
        // on the 'self' argument being passed by value.
        // This works but is not properly robust.
        tree.removeAll(.{ .discarder = &.{
            std.mem.Allocator.destroy,
            .{alloc},
        } });
        tree.deinit();
    }
```

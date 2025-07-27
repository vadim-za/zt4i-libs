# Intrusive trees quick howto

This document gives a quick howto-style introduction into intrusive trees support by the CC library. It is recommended to read the [Intrusive lists quick howto](intrusive-lists.md) first.

[Declaration](#tree-declaration)  
[Construction/destruction](#tree-constructiondestruction)  
[Node insertion](#tree-node-insertion)  
[Node removal](#tree-node-removal)  
[Inspection](#tree-inspection)

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
        // This should work at the moment, but is not
        // properly robust. One should generally use this
        // option with own and not library-declared functions.
        tree.removeAll(.{ .discarder = &.{
            std.mem.Allocator.destroy,
            .{alloc}, // the first argument(s) tuple
        } });
        tree.deinit();
    }
```

## Tree node insertion

In simple cases the nodes can be inserted using `insertNode()`. As with lists, for the sake of simplicity of demonstration, in the following examples we create and destroy nodes one-by-one, but this is not a must: node creation/destruction can be rather independent from their insertion/removal (as long as node lifetimes are respected).
```
    const node = try alloc.create(Node);
    // The hook field is assumed to be implicitly initialized
    // in the assignment below.
    node.* = .{
        .key = key_value,
        .field1 = value1,
        .field2 = value2,
    };
    const insertion_result = tree.insertNode(node, .{});
    if(insertion_result.success) {
        // insertion_result.node contains the inserted node
    } else {
        // insertion_result.node contains the conflicting node
        alloc.destroy(node);
    }
```
The insertion will fail if a node with an equal key is already contained in the tree, in which case the code above will destroy the node that we just created, which seems a bit inefficient. It is possible to delay the node construction until to the moment where it is established that the key is not present in the tree yet. Of course one could manually run a search for the key through the tree, but that will create another overhead of performing the same search twice (once to check for the key's presence and once again to the insert the node). Another option is to the `insert()` (rather than the `insertNode()`) method. The `insert()` method instead of accepting a node accepts an inserter functor:
```
    const Inserter = struct {
        alloc: std.mem.Allocator,
        key_value: i32,
        field1: Type1,
        field2: Type2,

        pub fn key(self: *const @This()) *const i32 {
            return &self.key_value;
        }
        fn produceNode(self: *const @This()) !*Node {
            const node = try self.alloc.create(Node);
            node.* = .{
                .key = self.key,
                .field1 = self.field1,
                .field2 = self.field2,
            };
            return node;
        }
    };
    // The insert() function will forward the error returned
    // by produceNode() (if any) to the caller
    const insertion_result = try tree.insert(&Inserter{
        .alloc = alloc,
        .key_value = key_value,
        .field1 = value1,
        .field2 = value2,
    }, .{});
    if(!insertion_result.success) {
        // We can somehow react to a failed insertion here
        // but do not need to destroy the node, since it
        // hasn't been created.
    }
```
N.B. The second argument of `insertNode()` and `insert()` is a retracer. Retracers are rarely needed and will be discussed separately. Typically, one leaves this argument empty.

## Tree node removal

The current CC's implementation of AVL trees doesn't store the pointer to the parent node in the tree nodes. Therefore it's not possible to simply remove a given node, one needs to search for the node starting from the root, one way or the other. For that reason the tree `remove()` function accepts a key value to search for, rather than a pointer to the node:
```
    // For the sake of demonstration's conciseness,
    // construct the node on stack
    var node: Node = .{
        .key = key_value,
        .field1 = value1,
        .field2 = value2,
    };
    tree.insertNode(&node, .{});
    .......
    // remove() returns the removed node or null
    // if the key is not found
    const remove_result = tree.remove(node.key, .{});
    std.debug.assert( remove_result == node );
```
N.B. Differently from `removeAll()`, the second argument of `remove()` is not a discarder but a retracer. Retracers are rarely needed and will be discussed separately. Typically one leaves this argument empty.

## Tree inspection

The following code illustrates the tree inspection features of CC trees.
```
fn walkFrom(from_node: ?*Node, tree: *MyTree) void {
    const node = from_node orelse return;

    // Returns *const [2]?*Node
    const chilren = tree.children(node);

    walkFrom(chilren[0], tree); // left node
    std.debug.print("{}\n", .{node.key});
    walkFrom(chilren[1], tree); // right node
}

fn walk(tree: *MyTree) void {
    // The following check is redundant, it's here
    // solely for the sake of demonstration
    if(!tree.hasContent())
        return;

    walkFrom(tree.root(), tree)
}
```

## Trees pub consts

Similarly to the lists, the types constructed by `zt4i.cc.Tree()` publish a number of pub consts. Consider the following definition of `MyTree`:
```
const MyTree = zt4i.cc.Tree(MyNode, .{
    .implementation = .avl,
    .hook_field = "hook",
    .compare_to = .useField("key", .default),
    .ownership_tracking = .{
        .owned_items = .container_ptr,
        .free_items = .on,
    },
});
```
The `MyTree` type defined as above has the following pub consts which can be used by the users of the CC library:
- `MyTree.Hook` - we are already familiar with this one
- `MyTree.Node` - equal to `MyNode`
- `MyTree.config` - equal to the second argument passed to `zt4i.cc.Tree()`
- `MyTree.InsertionResult` - the return type of tree's `insertNode()`. The return type of tree's `insert()` is `!MyTree.InsertionResult`.

# Trees

Here we are going to discuss the details specific to the tree containers.

[Implementations](#implementations)

[Node ordering](#node-ordering)
- [A node method](#a-node-method)
- [A freestanding function](#a-freestanding-function)
- [Using a field](#using-a-field)

[Callback forms](#callback-forms)
- [A closure-container-calback](#a-closure-container-callback)
- [A tuple-callback](#a-tuple-callback)

[Callback types](#callback-types)
- [Discarder callback](#discarder-callback)
- [Inserter callback](#inserter-callback)
- [Retracer callback](#retracer-callback)

[Ignoring the return values](#ignoring-the-return-values)

## Implementations

At the moment the CC library supports only AVL trees:
```
const MyTree = zt4i.cc.Tree(MyNode, .{
    .implementation = .avl,
    .....
};
```

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

### Simple trees

With `SimpleTree` and `SimpleTreeMap` the `compare_to` configuration field is automatically put under a `.useField()` specifier with the key field ("data" or "key" respectively) of the node. Thus one needs to specify the comparison method/function for the key field rather than for the node.
```
    const Payload = struct {
        value: i32,

        pub fn compareTo(
            self: *@This(),
            comparable_value_ptr: anytype
        ) std.math.Order {
            return switch (@TypeOf(comparable_value_ptr.*)) {
                // The method directly compares the Payload (which
                // simultaneously serves as a key for SimpleTree)
                // rather than a tree node. Therefore we don't need
                // special handling with comparable_value_ptr pointing
                // to a node, but we need one for the case it points
                // to the data field of a node.
                Data => self.compareTo(
                    &comparable_value_ptr.value,
                ),
                // This handles the case of various integer types.
                else => std.math.order(
                    self.value,
                    comparable_value_ptr.*,
                ),
            };
        }
    };

    const MyTree = SimpleTree(Payload, .{
        .implementation = .avl,
        .compare_to = .method("compareTo"),
        .ownership_tracking = .....,
    });
    ......
    const result = tree.insertNode(&node.data.value, &node);
    const found = tree.find(&0);
```

With `SimpleTree` and `SimpleTreeMap` the `.compare_to` configuration field also defaults to `.default` if omitted. As it's also automatically wrapped into `.useField()` we essentially get automatic comparison implementation in cases the node's key has a builtin numeric type or a pointer type:
```
    // No need to specify 'compare_to' here.
    const MyTree = SimpleTreeMap(i32, SomeData, .{
        .implementation = .avl,
        .ownership_tracking = .....,
    });
    ......
    const result = tree.insertNode(&node.key, &node);
    const found = tree.find(&0);
```

## Callback forms

In quite a number of methods one can or has to supply one or more callbacks. Generally trees support the two following common forms of specifying callbacks.

### A closure-container-callback

The callback is a container (typically a struct, possibly a union, unlikely an enum) object with a method of a predefined name and expected function signature. The callback is invoked by calling this method on the said struct object:
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
        tree.removeAll(.{ .discarder = discarder });
        tree.deinit();
    }
```
In the above example the discarder callback is expected to have a `discard()` method, accepting a node pointer and returning void, so this is what the struct type provides.

Notice that the callback is passed as a field of an anonymous struct literal. It is thereby passed
as a const value. The callback object might be copied a couple of times inside the tree code, therefore it makes sense to keep the object relatively small. If you need lots of data in the callback or if you need the callback to be mutable, you can store a pointer to the additional (possibly mutable) data in the callback, thereby keeping the callback itself small.

### A tuple-callback

You might be able to avoid having to declare a callback struct by passing the callback as an anonymous tuple literal:
```
    var tree: MyTree = .{};
    defer {
        // This discarder relies on details of declaration
        // of std.mem.Allocator.destroy(). In particular,
        // on the 'self' argument being passed by value.
        // This should work at the moment, but is not
        // properly robust. One should generally use this
        // option with own and not library-declared functions.
        tree.removeAll(.{ .discarder = .{
            std.mem.Allocator.destroy,
            .{alloc}, // the leading argument(s) tuple
        } });
        tree.deinit();
    }
```
In the above code the said anonymous tuple literal is assigned to the `discarder` field. Again, the entire tuple is thereby a const object, which might be copied a couple of times inside the tree code, so ideally the tuple should be kept rather small.

The tuple is expected to have 1 or two elements. The first one is the function to be called. The second one, if present, is a tuple of values to be passed as the leading arguments of the function call. Additional arguments may/will be supplied at the time of the callback invocation in the tree code. These additional arguments will be appended at the end. If the arguments tuple is not present, it is the same as if it was empty.

In the above example the callback invocation will result in the following call:
```
    std.mem.Allocator.destroy(alloc, node);
```
Similarly to the method-form callback, the `node` argument will be supplied by the tree code.

## Callback types

Different tree methods may expect different callbacks. Some callbacks may be obligatory, some may be optional. Each of these callbacks can take any of the common callback forms described above.

### Discarder callback

The `removeAll()` method, as demonstrated earlier, takes an optional `discarder` callback:
```
    // Use a discarder
    tree.removeAll(.{ .discarder = discarder_callback });
    // No discarder
    tree.removeAll(.{});
```
The discarder callback, if present, is called per removed node, so that e.g. one can destroy the node upon removal. It is not specified, in which order the nodes are removed.

The callback's expected forms are a container closure of the form
```
struct { // or any container
    .... fields ....
    // The method should be called "discard"
    pub fn discard(self: *const @This(), node: *Node) void {
        .....
    }
}
```
or a freestanding function of the form
```
// The function name can be anything, since the function will be
// explcitly passed in a tuple-form callback.
pub fn discard(
    leading arguments if any,
    node: *Node,
) void {
    .....
}
```
N.B. The 'node' argument (in both forms) actually can be anything which accepts a *Node value.

### Inserter callback

The inserted callback is used by tree's `insert()` method to potentially delay the construction of the node until is it known with certainty that the node needs to be inserted:
```
    const result = try tree.insert(&key, .{
        .inserter = inserter_callback,
    });
```
This callback is obligatory.

The callback's expected forms are a container closure of the form
```
struct { // or any container
    .... fields ....
    // The method should be called "produceNode".
    pub fn produceNode(self: *const @This()) !*Node {
        .....
    }
}
```
or a freestanding function of the form
```
// The function name can be anything, since the function will be
// explcitly passed in a tuple-form callback.
pub fn produceNode(
    leading arguments if any,
) !*Node {
    .....
}
```
The inserter callback must return an error union, regardless of whether it can actually fail. If it doesn't fail, just return an error union with an empty error set.

N.B. There is a third insertion callback form, which is simply a pointer to the node to be inserted:
```
    const node: *Node = .......;
    const result = try tree.insert(&node.key, .{
        .inserter = node,
    });
```
Instead of using this form, prefer using the `insertNode()` method.

### Retracer callback

The retracer callback is rarely used. It is called for nodes which have been just inserted into the tree, or whose position inside a tree has been just changed. It is intended to allow the user of the tree to cache tree-structure-related information inside the nodes. E.g. one could cache the subtree height for each node of the tree:
```
    const Retracer = struct {
        pub fn retrace(
            _: *const @This(),
            node: *Node,
            children: *const [2]?*Node,
        ) void {
            node.height = 1 +
                (if (children[0]) |ch| ch.height.? else 0) +
                (if (children[1]) |ch| ch.height.? else 0);
        }
    };

    const result = try tree.insertNode(&node.key, .{
        .retracer = Retracer{},
    });
    tree.removeNode(&node.key, .{
        .retracer = Retracer{},
    });
```
The function form of the retracer callback is
```
fn retrace(
    leading arguments if any,
    node: *Node,
    children: *const [2]?*Node,
) void {
    node.data = 1 +
        (if (children[0]) |ch| ch.data.? else 0) +
        (if (children[1]) |ch| ch.data.? else 0);
}
```
The retracer callback is optional and is available for `.insert()`, `.insertNode()` and `.remove()`. Notice that the first of the methods has an obligatory inserter callback, so the call looks like
```
    const result = try tree.insert(&key, .{
        .inserter = inserter_callback,
        .retracer = retracer_callback,
    });
```
or like
```
    const result = try tree.insert(&key, .{
        .inserter = inserter_callback,
    });
```
depending on the retracer callback presence.

N.B. The tree modification code doesn't try to optimize the number of retracer callback calls. If a number of position changes of one and the same node are occurring in a row, multiple retracer calls will be issued. So, generally a retracer shouldn't contain too performance-expensive code.

## Ignoring the return values

The tree insertion and removal functions do return result values, indicating the degree of success of performing the requested actions. Sometimes you are sure that a particular action will be successful. Here are a few patterns suggested for the cases when you do have such expectations.

```
    // An insertion that can fail to insert due to a key
    // collision, but cannot fail to produce a node
    const result = tree.insert(....) catch unreachable;

    // An insertion that cannot fail at all
    std.debug.assert((tree.insert(....) catch unreachable).success);

    // Same, but using insertNode()
    std.debug.assert(tree.insertNode(....).success);

    // A removal which is supposed to succeed
    std.debug.assert(tree.remove(&node.key) == node);

    // The same if you only know the key, but not the node
    std.debug.assert(tree.remove(&node.key) != null);
```
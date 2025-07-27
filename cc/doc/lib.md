# _Containers Collection_ library

The CC (Containers Collection) library implements a number of intrusive containers:
- double-linked lists
- single-linked lists
- AVL trees

It can be loosely thought of as a kind of Zig counterpart of `boost::intrusive`.
Non-intrusive-mode shortcuts are also provided.

Key features:
- API focuses on intrusive container use cases and scenarios.
- Uniform API (with minor differences) for all double-linked lists and for all single-linked lists, makes the respective list implementations fully or almost fully interchangeable.
- Configurable ownership-tracking features to aid catching of ownership-related usage errors.

[Construction/destruction](#constructiondestruction)  
- [Container construction/destruction](#container-constructiondestruction)
- [Node construction/destruction](#node-constructiondestruction)

[Container-specific APIs](#container-specific-apis)
- [Lists](lists.md)

## Construction/destruction

### Container construction/destruction

Most of the containers can be default-value-initialized. E.g:
```
fn someFunc(.....) ..... {
    // This initialization pattern is supported
    // by most containers
    var list: MyList = .{};
    defer list.deinit();
    ......
}
```
Containers with an embedded sentinel can be initialized only in-place:
```
fn someFunc(.....) ..... {
    // This initialization pattern is supported
    // by all containers
    var list: MyList = undefined;
    list.init();
    defer list.deinit();
    ......
}
```
Other containers _can_ be initialized in-place if desired (e.g. for implementation interchangeability).

The `deinit()` normally must be called for all containers, at least because it performs a run-time check for the container being emptied (in cases where it is a must) in debug builds.

### Node construction/destruction

Differently from C++'s `std` containers (and similarly to Zig's `std.DoublyLinkedList` and `std.SinglyLinkedList`) it is on you to (manually) allocate/deallocate memory for the nodes. The nodes can even be located on the stack, even in the form of local variables (as long as the variables' lifetimes are sufficiently large).

It is imperative that the hooks are initialized with `.{}` before the nodes are inserted into a container:
```
    // Option 1: all fields of the node have default initializers,
    // including the hooks, which are initialized to `.{}`
    var node1: Node = .{};

    // Option 2: the same, but the Node type is not accessible
    // here. No problem, we still have the same type accessible
    // via MyList
    var node2: MyList.Node = .{};

    // Option 3: we explicitly initialize all node fields except
    // the hooks, the latter have default initializers
    var node3: Node = .{
        .field1 = ......,
        .field2 = ......,
    };

    // Option 4: we explicitly initialize all fields:
    var node3: Node = .{
        .field1 = ......,
        .field2 = ......,
        .hook = .{},
    };

    // Option 4: we initialize the entire node to undefined
    // and then initialize the hook. Then we can insert the
    // node into the container, and initialize the remaining
    // fields later.
    var node4: Node = undefined;
    node4.hook = .{};

    // Option 5: we initialize the hook right before insertion
    var node5: Node = undefined;
    .......
    node5.hook = .{};
    list.insertFirst(&node5);
```
There is no `deinit()` function for the hooks, those can be simply discarded. You still might want to have a `deinit()` method for your node, though.

As mentioned, dynamic allocation/deallocation of the nodes needs to be done "manually":
```
    var node = alloc.create(Node);
    node.* = .{ ..... }; // at least initialize the hook
    list.insertFirst(node);
    .........
    if(list.popFirst()) |popped_node|;
        alloc.destroy(popped_node);
```

## Container-specific APIs

The container-specific APIs are discussed separately:

- [Lists](lists.md)

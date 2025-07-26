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

[Intrusive hooks](#intrusive-hooks)  
[Implementation selection](#implementation-selection)
- [Double-linked list implementations](#double-linked-list-implementations)
- [Single-linked list implementations](#single-linked-list-implementations)
- [Tree implementations](#tree-implementations)

[Ownership tracking](#ownership-tracking)
- [Owned item tracking](#owned-item-tracking)
- [Free item tracking](#free-item-tracking)

[Construction/destruction](#constructiondestruction)  
- [Container construction/destruction](#container-constructiondestruction)
- [Node construction/destruction](#node-constructiondestruction)

[Container-specific APIs](#container-specific-apis)
- [Lists](lists.md)

## Intrusive hooks

The primary CC container implementations rely on intrusive hooks embedded into the user's data structures. While `boost::intrusive` primarily places the intrusive hooks into base classes of C++ container nodes (which seems to be a more appropriate choice in C++), the CC library expects hooks to be fields of the container nodes. Here is an example:
```
const MyNode = struct {
    field1: Type1,
    field2: Type2,
    // Hook fields can have any name. This name must
    // be specified in the configuration of the respective
    // List.
    // Hooks must be initialized to .{} before the node
    // can be inserted into a container. In non-safe builds
    // this initializes all internal fields of the hook to
    // 'undefined' and thus should normally produce no code.
    // In safe and/or debug builds hooks may contain
    // additional fields.
    hook: MyList.Hook = .{},
};

const MyList = zt4i.cc.List(MyNode, .{
    .implementation = .......,
    .hook_field = "hook", // specify the hook field name
    .ownership_tracking = .....,
});
```

You can insert the same node into more than one container by embedding more than one hook into the node:
```
const MyNode = struct {
    field1: Type1,
    field2: Type2,
    hook1: MyList1.Hook = .{},
    hook2: MyList2.Hook = .{},
};

const MyList1 = zt4i.cc.List(MyNode, .{
    .implementation = .......,
    .hook_field = "hook1",
    .ownership_tracking = .....,
});

const MyList2 = zt4i.cc.List(MyNode, .{
    .implementation = .......,
    .hook_field = "hook2",
    .ownership_tracking = .....,
});
```

## Implementation selection

The double- and single-linked lists are provided with a number of different implementations in the CC library. The implementation is specified in the configuration parameter of the container. E.g.
```
const MyList = zt4i.cc.List(MyNode, .{
    // Select a double-linked list which uses null pointers
    // as termination sentinel values.
    .implementation = .{ .double_linked = .null_terminated },
    .hook_field = .......,
    .ownership_tracking = .....,
});
```

### Double-linked list implementations

NB. Differently from `std.DoublyLinkedList`, the available double-linked list implementations in the CC library do not explicitly store the number of list nodes.

The `.implementation` configuration field can assume following values for double-linked lists.

#### Null-terminated
```
const MyList = zt4i.cc.List(MyNode, .{
    .implementation = .{ .double_linked = .null_terminated },
    .....
};
```
A double-linked list using optional single-item pointers to store the `next` and `prev` links per node, as well as the `first` and `last` pointers in the list object itself. Null pointer values indicate going past the boundaries of the list contents. This is the most straightforward implementation and can be seen as the CC library's counterpart of `std.DoublyLinkedList`.

Under a wide range of conditions such list object can be trivially copied to another variable, since there are no pointers to/into the list object itself. _A notable exception to the latter is the case where the list pointer is being used as the ownership tracking token._ Notice, that even if a copy is possible, maintaining several copies of the same list in parallel is generally safe only as long as you don't manipulate the list.

#### Sentinel-terminated
```
const MyList = zt4i.cc.List(MyNode, .{
    .implementation = .{ .double_linked = .sentinel_terminated },
    .....
};
```
A double-linked list using an explicit sentinel object (embedded into the list object) for termination. This allows for (marginally) faster list manipulation (node insertion/removal). At the same time iterating through the list becomes more expensive due to Zig Issue #20254. There is hope that this issue is to be addressed soon, otherwise CC lists may get another iteration API, which works around the limitations of the said issue.  

Since there are pointers into the list object from the first/last nodes of the list, the list object is not copyable. Furthermore, differently from "copyable" lists, it cannot be "value-initialized" as `var list: MyList = .{};`, but must be initialized in-place:
```
fn someFunc(......) ..... {
    var list: MyList = undefined;
    // Sentinel-terminated lists must be initialized in-place
    list.init();
    // Normally you shoud deinit all lists
    defer list.deinit(); 
    ....
}
```
Notice that for API compatibility reasons, the in-place initialization `list.init()` is supported by all list implementations, while "value initialization" is not available for the sentinel-terminated lists.

#### Single-pointer
```
const MyList = zt4i.cc.List(MyNode, .{
    .implementation = .{ .double_linked = .single_ptr },
    .....
};
```
The list object is smaller than normally, since it stores only the pointer to the first node, instead of storing the pointers to both first and last nodes. This results in (marginally) slower list iteration and insertion, but saves memory used for the list object itself (not the list nodes). It can be useful for memory-intensive data structures, where one begins to care more about object sizes.

There are no pointers into the list (unless the list pointer is used as an ownership token), therefore the list is copyable under conditions similar to the ones for the null-terminated double-linked list.

### Single-linked list implementations

The single-linked list implementations provided by the CC library all use null-pointers as termination sentinel values. The `.implementation` configuration field can assume following values for single-linked lists.

#### Single-pointer
```
const MyList = zt4i.cc.List(MyNode, .{
    .implementation = .{ .single_linked = .single_ptr },
    .....
};
```
A single-linked list which stores the pointer to the first node. This is the most straightforward implementation and can be seen as the CC library's counterpart of `std.SinglyLinkedList`.

The list can be copied under conditions similar to the ones for copyable double-linked lists.

#### Double-pointer
```
const MyList = zt4i.cc.List(MyNode, .{
    .implementation = .{ .single_linked = .double_ptr },
    .....
};
```
A single-linked list which stores the pointers to the first and last nodes. Compared to the single-pointer version, this one additionally allows insertion of nodes at the end of the list.

The list can be copied under conditions similar to the ones for copyable double-linked lists.

### Tree implementations
At the moment the CC library supports only AVL trees:
```
const MyTree = zt4i.cc.Tree(MyNode, .{
    .implementation = .avl,
    .....
};
```

## Ownership tracking

The ownership tracking is configured by two separate parameters: tracking of owned items and tracking of free items:
```
const MyList = zt4i.cc.List(MyNode, .{
    .implementation = .......,
    .hook_field = ......,
    .ownership_tracking = .{
        .owned_items = ......,
        .free_items = .....,
    },
});
```
NB. In the current state of the CC library the ownership tracking is considered as a pretty abstract feature, therefore it speaks of container items rather than container nodes, from a POV that container item is a more generic concept than container node.

### Owned item tracking

The owned item tracking features, when enabled, track the owning container for each item (node) inserted into a container. This allows to detect situations when items are supplied to wrong containers (e.g. for removal, for iterating to the next node, etc.).

NB. This doesn't explicitly track the state of an item being inserted or not inserted into a container. The owner item tracking assumes that all items which are supposed to be inserted into a given container are at least inserted into _some_ container, it merely checks that the container is the right one. If you are also concerned about inadvertently misusing the items which are not inserted into any container, you need to enable the free item tracking (but this comes at some extra costs). _Without enabled free item tracking, free items will cause undefined check results in places where owned items are expected._

The following owned item tracking modes are supported (for double- and single-linked lists as well as for the trees).

### Off
```
const MyList = zt4i.cc.List(MyNode, .{
    ........
    .ownership_tracking = .{
        .owned_items = .off,
        .free_items = .....,
    },
});
```
The owning container is not tracked for the items, thus there are no (however minor) extra costs. _This mode is also used in non-debug builds, regardless of what's specified in the container's configuration._

### Pointer to the container
```
const MyList = zt4i.cc.List(MyNode, .{
    ........
    .ownership_tracking = .{
        .owned_items = .container_ptr,
        .free_items = .....,
    },
});
```
The pointer to the container object is used as the ownership token. That is this pointer is being stored inside the nodes which are inserted into the container and is used in a number of operations to check if the container is the expected one. This creates the following limitations:
- The container's address cannot be changed, thereby the container becomes non-copyable.

### Custom token
```
const token_type: type = .....;

const MyList = zt4i.cc.List(MyNode, .{
    ........
    .ownership_tracking = .{
        .owned_items = .{ .custom = token_type },
        .free_items = .....,
    },
});
```
Instead of using a pointer to the container a custom token value is used. This allows the container to still be copied (unless other reasons prevent it), since the token is unchanged by copying the container.

The token type must support the `==` comparison operation. Normally one would use integer types.

The custom token must be explicitly set after the container's initialization (but before any nodes are inserted into the container):
```
const MyList = zt4i.cc.List(MyNode, .{
    ........
    .ownership_tracking = .{
        .owned_items = .{ .custom = i32 },
        .free_items = .....,
    },
});

fn someFunc(.....) .... {
    // Normally you need some kind of token allocation mechanism
    // ensuring that different (compatible to each other) containers
    // get different tokens. Here we simply set the token to 1.
    var list: MyList = .{};
    list.setOwnershipToken(1);
}
```

### Free item tracking

The free item tracking features, when enabled, track for each item (node), whether it is inserted into a container (owned) or not (free). This allows to detect situations when items are inserted twice (possibly into a different container) or when a free item is removed from a container.

The free item tracking comes at a cost:
- You must explicitly remove items from a container, if free item tracking is enabled. Otherwise (if free item tracking is not enabled) you can simply discard the container. The `deinit()` methods of the containers perform the respective checks:
```
    // Fails if free item tracking is enabled for the container
    // and the container is non-empty.
    list.deinit();
```

The following owned item tracking modes are supported (for double- and single-linked lists as well as for the trees).

#### Off
```
const MyList = zt4i.cc.List(MyNode, .{
    ........
    .ownership_tracking = .{
        .owned_items = .....,
        .free_items = .off,
    },
});
```
The owned/free state is not tracked for the items, thus there are no extra costs (mostly associated with the need to explicitly remove items from the container). _This mode is also used in non-debug builds, regardless of what's specified in the container's configuration._

#### On
```
const MyList = zt4i.cc.List(MyNode, .{
    ........
    .ownership_tracking = .{
        .owned_items = .....,
        .free_items = .on,
    },
});
```
The owned/free state is tracked per item. You must explicitly remove all items from the container before you discard/destroy the container.

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

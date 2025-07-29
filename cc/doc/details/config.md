# Container configuration

The CC library container type construction functions, such as `zt4i.cc.List`, `zt4i.cc.SimpleList` etc. accept a configuration parameter. The fields present in this parameter somewhat vary across different functions, but they are still largely similar. Here we are going to discuss the most common of these fields and what they specify and affect.

[Implementation selection](#implementation-selection)

[Intrusive hooks](#intrusive-hooks)  

[Ownership tracking](#ownership-tracking)
- [Owned item tracking](#owned-item-tracking)
- [Free item tracking](#free-item-tracking)

## Implementation selection

CC container may have a number of differnet implementations, selected by the `.implementation` field of the container configuration parameter:
```
const MyList = zt4i.cc.List(MyNode, .{
    .implementation = .{ .double_linked = .null_terminated },
    .........
});
```
The available implementations are covered separately for different container types:
- [List implementations](lists.md#implementations)
- [Tree implementations](trees.md#implementations)


# Intrusive hooks

The intrusive hooks are technical data structures which need to be present in the nodes to allow them to be inserted into the respective containers. E.g. a double-linked list hook will contain the `prev` and the `next` fields, as well as potentially some further data.

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
    // additional fields which are initialized to certain
    // "defined" values.
    hook: MyList.Hook = .{},
};

const MyList = zt4i.cc.List(MyNode, .{
    .hook_field = "hook", // specify the hook field name
    .........
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
    .hook_field = "hook1",
    .........
});

const MyList2 = zt4i.cc.List(MyNode, .{
    .hook_field = "hook2",
    .........
});
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

#### Owned item tracking off
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

#### Owned item tracking via pointer to the container
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

#### Owned item tracking via custom token
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

#### Free item tracking off
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

#### Free item tracking on
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

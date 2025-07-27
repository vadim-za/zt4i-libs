# Non-intrusive containers quick howto

This document gives a quick howto-style introduction into non-intrusive containers support by the CC library. This support is built by providing non-intrusive wrappers on top of intrusive container functionality. The biggest part of the intrusive functionality is reused by non-intrusive containers, therefore it is recommended to read the respective intrusive howto's first:
- [Intrusive lists quick howto](intrusive-lists.md)
- [Intrusive trees quick howto](intrusive-trees.md)

It should be pointed out that there is no fundamental difference between CC's intrusive and non-intrusive container structure. The difference is just in how the container types are specified. While intrusive containers expect hooks to be embedded into the user's data type, non-intrusive containers combine the user data type(s) and the intrusive hook into a larger data structure, that's pretty much all (save a few details). CC's non-intrusive containers still do not do memory management on their own, the node allocation/deallocation needs to be done by the user.

[Non-intrusive lists](#non-intrusive-lists)  
[Non-intrusive trees](#non-intrusive-trees)
- [Set trees](#set-trees)
- [Map trees](#map-trees)

## Non-intrusive lists

While intrusive lists are constructed using `zt4i.cc.List()`, non-intrusive lists are constructed using `zt4i.cc.SimpleList()`. The following example demonstrates:
```
const Payload = struct {
    field1: Type1,
    field2: Type2,
};

// Notice that we supply Payload instead of MyNode.
// Also we do not supply the hook field name.
const MyList = zt4i.cc.SimpleList(Payload, .{
    .implementation = .{ .double_linked = .null_terminated },
    .ownership_tracking = .{
        .owned_items = .container_ptr,
        .free_items = .on,
    },
});
```
The `MyList.Node` type will thereby automatically get the following structure:
```
struct {
    // The hook has a default initializer
    hook: MyTree.Hook = .{},
    data: Payload,
}
```
Other than that, `MyList` will be the same as if constructed by `zt4i.cc.List()`.

N.B. `Payload` doesn't have to be a struct. E.g. one can construct a list of 32-bit integers as
```
const MyList = zt4i.cc.SimpleList(i32, .{
    .........
});
```

## Non-intrusive trees

Trees do not simply carry the payload, but their nodes must be ordered (usually based on the key value). CC library provides two helpers for construction of non-intrusive tree types

### Set trees

In case the payload _is_ the key value, the tree basically functions like a set. The following example illustrates:
```
// In simple cases, where the payload is a type supported
// by std.math.order(), or is a single-item pointer type,
// we do not need to supply the '.compare_to' value.
// By default, the SimpleTree will use such payload as the
// key.
const MyTree = zt4i.cc.SimpleTree(i32, .{
    .implementation = .avl,
    .ownership_tracking = .{
        .owned_items = .container_ptr,
        .free_items = .on,
    },
});
```
The `MyTree.Node` type will thereby automatically get the following structure:
```
struct {
    // The hook has a default initializer
    hook: MyTree.Hook = .{},
    data: i32,
}
```
As mentioned, the `data` field will automatically serve as the key. We can thereby use `i32`-compatible values for node search and removal.

### Map trees

The second helper is usable in the cases where it is convenient to separate the key from the rest of the payload. This basically means the tree functions as a map:
```
const Payload = struct {
    field1: Type1,
    field2: Type2,
};

// We are using i32 type as the key, like in the previuos
// example. Like in the previous example, we do not need
// to supply the '.compare_to' value.
const MyTree = zt4i.cc.SimpleTreeMap(i32, Payload, .{
    .implementation = .avl,
    .ownership_tracking = .{
        .owned_items = .container_ptr,
        .free_items = .on,
    },
});
```
The `MyTree.Node` type will thereby automatically get the following structure:
```
struct {
    // The hook has a default initializer
    hook: MyTree.Hook = .{},
    key: i32,
    data: Payload,
}
```
The `key` field will automatically serve as the key.

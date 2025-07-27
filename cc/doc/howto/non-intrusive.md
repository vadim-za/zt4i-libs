# Non-intrusive containers quick howto

This document gives a quick howto-style introduction into non-intrusive containers support by the CC library. This support is built by providing non-intrusive wrappers on top of intrusive container functionality. The biggest part of the intrusive functionality is reused by non-intrusive containers, therefore it is recommended to read the respective intrusive howto's first:
- [Intrusive lists quick howto](intrusive-lists.md)
- [Intrusive trees quick howto](intrusive-trees.md)

It should be pointed out that there is no fundamental difference between CC's intrusive and non-intrusive container structure. The difference is just in how the container types are specified. While intrusive containers expect hooks to be embedded into the user's data type, non-intrusive containers combine the user data type(s) and the intrusive hook into a larger data structure, that's pretty much all (save a few details).

## Non-intrusive lists

While intrusive lists are constructed using `zt4i.cc.List()`, non-intrusive lists are constructed using `zt4i.cc.SimpleList()`:
```
const Payload = struct {
    field1: Type1,
    field2: Type2,
};

// Notice that we supply Payload instead of MyNode.
// Also we do not
const MyList = zt4i.cc.SimpleList(Payload, .{
    .implementation = .{ .double_linked = .null_terminated },
    .ownership_tracking = .{
        .owned_items = .container_ptr,
        .free_items = .on,
    },
});
```

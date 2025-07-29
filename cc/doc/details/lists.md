# Lists

Here we are going to discuss the details specific to the tree containers.

[Implementations](#implementations)
- [Double-linked list implementations](#double-linked-list-implementations)
- [Single-linked list implementations](#single-linked-list-implementations)

## Implementations

The double- and single-linked lists are provided with a number of different implementations in the CC library. The implementation is specified in the configuration parameter of the container. E.g.
```
const MyList = zt4i.cc.List(MyNode, .{
    // Select a double-linked list which uses null pointers
    // as termination sentinel values.
    .implementation = .{ .double_linked = .null_terminated },
    .........
});
```

### Double-linked list implementations

NB. Differently from `std.DoublyLinkedList`, the available double-linked list implementations in the CC library do not explicitly store the number of list nodes.

The `.implementation` configuration field can assume following values for double-linked lists.

#### Null-terminated double-linked lists
```
const MyList = zt4i.cc.List(MyNode, .{
    .implementation = .{ .double_linked = .null_terminated },
    .....
};
```
A double-linked list using optional single-item pointers to store the `next` and `prev` links per node, as well as the `first` and `last` pointers in the list object itself. Null pointer values indicate going past the boundaries of the list contents. This is the most straightforward implementation and can be seen as the CC library's counterpart of `std.DoublyLinkedList`.

Under a wide range of conditions such list object can be trivially copied to another variable, since there are no pointers to/into the list object itself. _A notable exception to the latter is the case where the list pointer is being used as the ownership tracking token._ Notice, that even if a copy is possible, maintaining several copies of the same list in parallel is generally safe only as long as you don't manipulate the list.

#### Sentinel-terminated double-linked lists
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

#### Single-pointer double-linked lists
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

#### Single-pointer single-linked lists
```
const MyList = zt4i.cc.List(MyNode, .{
    .implementation = .{ .single_linked = .single_ptr },
    .....
};
```
A single-linked list which stores the pointer to the first node. This is the most straightforward implementation and can be seen as the CC library's counterpart of `std.SinglyLinkedList`.

The list can be copied under conditions similar to the ones for copyable double-linked lists.

#### Double-pointer single-linked lists
```
const MyList = zt4i.cc.List(MyNode, .{
    .implementation = .{ .single_linked = .double_ptr },
    .....
};
```
A single-linked list which stores the pointers to the first and last nodes. Compared to the single-pointer version, this one additionally allows insertion of nodes at the end of the list.

The list can be copied under conditions similar to the ones for copyable double-linked lists.

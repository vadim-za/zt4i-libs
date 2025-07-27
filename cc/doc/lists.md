# List-specific APIs

- [Iteration/inspection](#iterationinspection)
- [Insertion](#insertion)
- [Removal](#removal)
- [Non-intrusive wrapper](#non-intrusive-wrapper)

## Iteration/inspection

```
    // Forward-iteration of (any) double-linked
    // or (any) single-linked list
    var node = list.first(); // node's type is '?*Node'
    while(node) |n| : (node = list.next(n)) {
        // n's type is '*Node'
        doSomething(n);
    }

    // Backward-iteration of (any) double-linked list
    var node = list.last(); // node's type is '?*Node'
    while(node) |n| : (node = list.prev(n)) {
        // n's type is '*Node'
        doSomething(n);
    }

    // Just checking whether the list contains any nodes
    if(list.hasContents())
        std.debug.print("List is non-empty\n", .{});
```
The `first()`, `last()`, `next()` and `prev()` methods are not restricted to iterating through the whole list, they can be freely used for a generic list inspection.

## Insertion

For the sake of example simplicity, the nodes are allocated on stack in the form of local variables. In a more realistic example, the nodes would be rather dynamically allocated by hand. (In an even more realistic example, since we're focusing on intrusive containers, the nodes could be preallocated in advance).
```
    // Below we assume that Node is declared with default
    // initializers for all fields, including the hook!
    var node1: Node = .{};
    list.insertFirst(&node1);

    // N.B. Insertion at the last position is not available for
    // single-pointer single-linked lists.
    var node2: Node = .{};
    list.insertLast(&node2);

    // N.B. Insertion before a node is available only for
    // double-linked lists.
    var node3: Node = .{};
    list.insertBefore(&node2, &node3);

    // Insertion after a node is available for all lists
    var node4: Node = .{};
    list.insertAfter(&node1, &node4);
```
There is also a more elegant form of expressing the above using a single `insert` method. The potential drawback is that this form relies on the compiler optimizing the extra operations related to handling the first argument ("insertion position"). So one might want to avoid this form in highly performance-critical code.
```
    // The restrictions on specific insertion features
    // (depending on the list type) are the same as in
    // the example above.

    list.insert(.first, &node1);
    list.insert(.last, &node2);
    list.insert(.before(&node2), &node3);
    list.insert(.after(&node1), &node4);

    // .before() and .after() actually accept optional pointers.
    // The semantics of null values is illustrated below:

    // This is the same as insertLast()
    list.insert(.before(null), &node5);

    // This is the same as insertFirst()
    list.insert(.after(null), &node6);
```

## Removal

```
    // We assume that the 'node1' is set to point to some
    // node contained in the `list'. The list must be
    // double-linked (there is no remove() method for
    // single-linked lists)
    const node1: *Node = .......;
    list.remove(node1);

    // The previous example doesn't deallocate the node.
    // If the node was dynamically allocated, we could do
    // the following:
    list.remove(node2);
    alloc.destroy(node2);

    // For single-linked lists we have removeFirst()
    list.removeFirst(node3);
    alloc.destroy(node3);

    // The pop functions are shortcuts combining list inspection
    // and node removal. Here we assume that the nodes were
    // dynamically allocated. Note that popLast() is only available
    // for double-linked lists.
    if(list.popFirst()) |node|
        alloc.destroy(node);
    if(list.popLast()) |node|
        alloc.destroy(node);

    // This pattern can be used to destroy all nodes in a list,
    // assuming the nodes were dynamically allocated. It doesn't
    // matter much if we use popFirst() or popLast().
    while(list.popLast()) |node|
        alloc.destroy(node);

    // If we only need to remove all nodes from the list without
    // deallocating them, it's faster to use removeAll(). This
    // function is available for all lists.
    list.removeAll();
```

## Non-intrusive wrapper

While the primary focus of the library is intrusive container support, it provides a few wrappers for non-intrusive use cases, similar to `std.DoublyLinkedList`, `std.SinglyLinkedList` etc.

The `Simplelist` wrapper produces list nodes similar to the ones used by `std.DoublyLinkedList` and `std.SinglyLinkedList`:
```
    const MyList = zt4i.cc.SimpleList(i32, .{
        .implementation = .......,
        .ownership_tracking = ......,
    });
    var list: MyList = .{};
    // We didn't declare an own Node type. Instead it has been
    // constructed by SimpleList() for us. We can access this
    // type under 'MyList.Node'.
    // The SimpleList's node has the `data` field of the type
    // supplied to SimpleList() and the `hook` field. The latter
    // has a default initializer, therefore it can be omitted
    // below:
    var node: MyList.Node = .{ .data = 0 };
    list.insertFirst(&node);
    .....
```

# _Containers Collection_ library

The CC (Containers Collection) library implements a number of intrusive containers:
- double-linked lists
- single-linked lists
- AVL trees

It can be loosely thought of as a kind of Zig counterpart of `boost::intrusive`.
Non-intrusive-mode shortcuts are also provided.

Key features:
- API focuses on intrusive container use cases and scenarios.
- Uniform API (with minor differences) for all double-linked lists and for all single-linked lists makes the respective list implementations fully or almost fully interchangeable.
- Configurable ownership-tracking features to aid catching of ownership-related usage errors.
- Configurable handling of key values and node construction for trees.
- Non-intrusive wrappers for simpler use cases.

It is recommended to read the howto-s in the given below order, and to read the howto-s before reading the details part of the documentation.

**Howto-s**
- [Intrusive lists](howto/intrusive-lists.md)
- [Intrusive trees](howto/intrusive-trees.md)
- [Non-intrusive containers](howto/non-intrusive.md)

**Details**
- [Container configuration](details/config.md)
- [Lists](details/lists.md)
- [Trees](details/trees.md)

 You can also check the commits [ddd321](https://github.com/vadim-za/zt4i-libs/commit/ddd321bad4eaae24fabc3a915e38015729d66430) and [796f50](https://github.com/vadim-za/zt4i-libs/commit/796f504150ce49d05392519b368115b2a662911a) which switch the GUI library from using `std.DoublyLinkedList` to using CC lists, thereby providing a demonstration of some of the differences between CC and `std` lists.

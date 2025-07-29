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
- Configurable key values handling and node construction for trees.
- Non-intrusive wrappers for simpler use cases.

It is recommended to read the howto-s in the given order, and to read the howto-s before reading the details part of the documentation.

**Howto-s**
- [Intrusive lists](howto/intrusive-lists.md)
- [Intrusive trees](howto/intrusive-trees.md)
- [Non-intrusive containers](howto/non-intrusive.md)

**Details**
- [Container configuration](details/config.md)
- [Lists](details/lists.md)
- [Trees](details/trees.md)

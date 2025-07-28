# Trees

Here we are going to discuss the details specific to the tree containers.

## Node ordering

Sorted trees need to order their nodes. On a purely intuitive level, we would like to simply to apply `std.math.order()` to the nodes. There are however a number of problems with that:
- `std.math.order()` is restricted to numeric types and cannot be used to compare tree nodes.
- Rather than comparing nodes we need to compare their keys, or, even more commonly, we need to compare a node's key to an explicitly supplied key value.
- Usually the keys are present as explicitly stored values (in variables or in structure fields) of one and the same type. However, in more complicated situations the key can be stored in a number of different forms/types. For that reason, the CC library's tree implementation implements the ordering comparison between a node and a "comparable value", whatever the latter may be.
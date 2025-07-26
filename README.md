# ZT4I (Zig Tools For Innovation) Libraries

**Supported Zig version: 0.14.1**

The list of libraries:

1. **GUI** - a minimal platform-agnostic UI windowing library. At the moment supports only the Windows x64 platform. No immediate plans to support other platforms in the nearest future, but the API is laid down in a platform-abstract way (although almost certainly it will need to be adjusted in order to efficiently support further platforms). For the time being can be functionally seen as a (much smaller) parallel to MFC.  
Documentation is planned, for the time being the demo application serves in that quality.

2. **CC** - "containers collection" library with a focus on intrusive container features. Platform-agnostic. Contains highly-configurable lists and trees (including set- and map-style usage). One can choose among different implementations and ownership tracking modes.  
Documentation is planned, in the meantime you can check the unit tests. Also check the commits [ddd321](https://github.com/vadim-za/zt4i-libs/commit/ddd321bad4eaae24fabc3a915e38015729d66430) and [796f50](https://github.com/vadim-za/zt4i-libs/commit/796f504150ce49d05392519b368115b2a662911a) which switch the GUI library from using `std.DoublyLinkedList` to using CC lists.

The plan is to add one further platform-agnostic library as well as a more realistic demo app in next months.

## Demo application

This application's source code is intended to showcase the usage of the library features and serve as a quick "howto" documentation. You might need to read the source to see what the application is actually supposed to do in response to which actions.

## Building and using

Building with the `build.zig` (on a Windows x64 platform) should produce a demo application. To use the libraries by another project, you can add it as a dependency.

Alternatively you could simply manually add the `zt4i.zig` file to your project's build as a module root.

## API stability

The libraries' API is somewhat stable, but not really. The libraries are nowhere close to a 1.0 release.

## Usage/contributions

A mild amount of interest, usage and feedback would be appreciated. However, at least until the project reaches a more mature state (think months or a couple of years, maybe) no external contributions will be accepted. This is in order to stay focused and keep a single consistent vision. Later this policy might be changed.

## Bugs

Probably there are quite some. The libraries are a heavy work in progress, either use them "AS IS" or just don't.

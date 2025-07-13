# ZT4I (Zig Tools For Innovation) Libraries

**Supported Zig version: 0.14.1**

The list of libraries:

1. **GUI** - a minimal platform-agnostic UI windowing library. At the moment supports only the Windows x64 platform. No immediate plans to support other platforms in the nearest future, but the API is laid down in a platform-abstract way (although almost certainly it will need to be adjusted in order to efficiently support further platforms).

The plan is to add further libraries as well as a more realistic demo app in next months. The former are intended to be platform-independent.

## Demo application

This application's source code is intended to showcase the usage of the library features and serve as a quick "howto" documentation. Also you might need to read the source to see what the application is actually supposed to do in response to which actions.

## Building and using

Building with the `build.zig` (on a Windows x64 platform) should produce a demo application. To use the libraries from another project, you can add it as a dependency.

Alternatively you could simply manually add the `zt4i.zig` file to your project's build as a module root.

## API stability

The libraries' API is somewhat stable, but not really. The libraries are nowhere close to a 1.0 release, they even don't have versioning yet, and if there were, it probably would have been something like 0.0.1.

## Usage/contributions

A mild amount of interest, usage and feedback would be appreciated. However, at least until the project reaches a more mature state (think months or a couple of years, maybe) no external contributions will be accepted. This is in order to stay focused and keep a single consistent vision. Later this policy might be changed.

## Bugs

Probably there are quite some. The libraries are a heavy work in progress, either use them "AS IS" or just don't.

<!-- SPDX-License-Identifier: 0BSD -->

# System libarchive interface

Mallow links the operating system's libarchive using this SwiftPM system-library target. It does not redistribute an implementation, install Homebrew or download a new extraction dependency at first launch.

The tested macOS SDK did not provide archive.h. `shim.h` therefore has a minimal set of public libarchive 3 ABI declarations, checked against Apple's published `archive.h` and `archive_entry.h`. Hosts with the system headers include them instead. Declarations are not a copy of libarchive's implementation. No private/internal archive symbol is used.

References:
- https://github.com/apple-oss-distributions/libarchive/tree/main/libarchive/libarchive
- https://github.com/libarchive/libarchive/blob/master/libarchive/archive_read.3

The current Mac CI links and exercises the real reader and synthetic writer, and installs the pinned Wine archive. This is not evidence of every supported-OS/toolchain combination. Linux contributors need their system libarchive development package. The system implementation retains its upstream licences; Mallow's bridge/header comments are 0BSD.

Input/path policies are implemented in MallowKit's ArchiveExtractor, not delegated to archive extraction metadata. See `docs/runtime-installation.md` for limits and the separate installed-file verification boundary.

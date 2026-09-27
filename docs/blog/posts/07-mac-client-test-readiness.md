---
# SPDX-License-Identifier: 0BSD
date: 2026-09-27
authors:
  - mixutin
categories:
  - Project
slug: mac-client-test-readiness
description: Local client checks, private diagnostics, matching debug symbols and a concrete Mac testing workflow.
---

# Making the next Mac test useful

A downloadable app is only the start of a useful test. This preview adds **Run client checks**, **Export report…** and the matching `mallow diagnostics` command, so a report identifies its build, prerequisites and observed timings.

<!-- more -->

Local checks exercise small private scratch files, locks, a known checksum and the download policy. Wine and GStreamer receive bounded architecture-header inspection, not execution. Reports omit raw logs, personal paths, environment variables and vendor payloads; nothing uploads automatically.

The build pipeline packages optimized and debug apps with UUID-matched dSYMs, exact tracked sources and a Mac test kit. A packaged-binary check on macOS 15 is a release gate alongside the macOS 26 build and real-archive installation checks. CI outcomes remain separate from graphical usability, debugger behavior and performance on a person's Mac.

This checks off scoped testing and diagnostics work on the roadmap, not the Windows-launch milestone. Bottles, full dependency setup, the launch planner and the kernel sandbox remain unfinished. Follow the [Mac testing guide](../../mac-client-testing.md) and record actual results in [issue #48](https://github.com/mixutin/Mallow/issues/48).

# Explicit geometry overlay for Release compilation

The viewer's Domain module may explicitly import CoreGraphics for the geometry types it already
uses through Foundation. This is a narrow exception to the Foundation-only Domain rule, approved
by Davide on 23 October 2026 while investigating the missing 0.23.0 TestFlight build. It permits no
drawing, platform interaction or I/O in Domain and adds no external package dependency.

Xcode Cloud build 178 started automatically for the merge of
[PR #128](https://github.com/fardavide/granita/pull/128). Its iOS archive failed in Swift 6.4's
`PerformanceSILLinker` while deserializing the touch-state value's hold-begin method; the retained
frontend crash report records a segmentation fault. TestFlight distribution was skipped.

An unsigned physical-device Release compile reproduced the compiler crash locally with the same
Swift compiler version, `swiftlang-6.4.0.34.1`. Adding the explicit CoreGraphics import made the same
build pass without changing behavior, optimization settings or callback signatures. The full
package tests, both unsigned app builds, resolver validation and a second device Release compile
also pass on the final 0.23.1 sources.

[Swift issue #92222](https://github.com/swiftlang/swift/issues/92222) documents a matching
Foundation/CoreGraphics overlay mismatch during cross-module optimization on this compiler. A
Foundation-only producer and a consumer loading CoreGraphics can disagree about the imported fields
of geometry structs. The explicit import gives the producing module the same geometry overlay as
its SwiftUI consumer. The import carries a comment so it is not removed as apparently redundant.

The required iOS CI build currently compiles Debug simulator products and did not exercise this
Release path. Davide chose the archive repair alone, without adding a Release CI check. The
temporary Make command used to reproduce and verify the failure is not part of the shipped change.

This failure differs from the previous missing automatic trigger: Cloud build 177 for the previous
merge was started manually and succeeded, while build 178 was automatic and failed compilation.
The separate post-merge GitHub CI run also failed simulator availability checks; that blocked the
Mac release workflow independently of the iOS archive failure.

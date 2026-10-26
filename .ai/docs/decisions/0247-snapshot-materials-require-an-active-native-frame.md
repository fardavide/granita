# Snapshot materials require an active native frame

The live-window snapshot harness prepares the actual key-window scene before mounting its
subject. Both that scene and the application must be active, and a native display callback must
observe those states. A conditional request opens the app's existing URL scheme when activation
is needed. No request is made for an already active host. Missing scenes, rejected activation and
a ten-second setup deadline record a failing setup issue; none permits a successful image verdict.

CI run [40233647872](https://github.com/fardavide/granita/actions/runs/40233647872) failed the dark
image comparison on the Done capsule's native material. Its image precision was 0.9979973 against
0.999, and its perceptual precision was 0.71281254 against 0.87. Local cold launches reproduced
those exact values while the app and scene were inactive. Waiting for sixty native frames while
inactive retained the failure. Window-style and replacement-window experiments did not reliably
repair it.

Two further cold launches captured each raster as immutable PNG data while its host was still
mounted and reconstructed fresh image objects for every comparison. Both retained the exact
mismatch before activation and on the immediate active capture. The next native frame matched
the unchanged baseline with the same host, window and geometry. Independent native pixel decoding
confirmed image content remained present. A third fixed launch was already active and is
inconclusive for causality. The original snapshot helper also passed a freshly mounted view
immediately after the next-frame capture in the second eligible launch.

The setup waits for observed readiness rather than an arbitrary delay or an image comparison.
Actual active states and a native frame are sufficient; the URL completion may arrive later.
Every capture keeps its existing configuration, baseline and tolerances. The original sixteen
image-comparison cases pass with this preparation. Broader suite and required CI verification
remain pending.

Native motion fixtures also use the returned key-window scene before mounting. A cold performance
comparison was initially inactive, so this keeps subsequent comparisons under the same active
conditions. Preparation ends before motion sampling and changes none of its limits.

This does not explain the collapse stall: its dense successor fixture still fails while its app
and scene stay active throughout. That failure retains its separate reproduction and original limits.

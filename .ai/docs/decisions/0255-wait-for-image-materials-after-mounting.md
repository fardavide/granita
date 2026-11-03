# Wait for image materials after mounting

30 October 2026.

## Evidence

[CI 392](https://github.com/fardavide/granita/actions/runs/40971849516) fails the held-image
iPhone-dark comparison at the Done button's native material. Image precision is 0.99739075
against 0.999, and perceptual precision is 0.67562497 against 0.87. The picture, text and layout
match. The scene preparation introduced by 0247 observes an active frame before mounting the
subject; that observation says nothing about the subject's first rendered frame.

A local two-arm control uses fresh hosting controllers, the same native snapshot strategy,
configuration, locale, baseline and full-image comparator. Immediate capture reproduces both
CI precision values and the Done-only difference. Waiting for one counted native display
callback after a qualifying mounted layout matches the baseline. Application and scene remain
active, the hosting window remains key, and the host, view and navigation bar have dark traits.

Reversing the order in a fresh process passes both arms: the counted-frame capture succeeds
first, and a subsequent immediate capture succeeds too. Prior rendering state matters. This
does not establish that every fresh host needs another frame, or that a callback universally
proves material settlement. The unchanged image comparator remains the verdict.

The public appearance callback is not delivered by this snapshot path. The qualifying hook is
`viewDidLayoutSubviews`; the initial appearance-hook control fails feasibility and is not a
snapshot regression result.

## Decision

Image comparisons opt into one post-mount native frame through the shared snapshot helper.
The option defaults off. Scene activation and keyboard preparation remain in place.

The hosting controller arms its observer only after observing the expected scene, key window,
active application and scene, and requested host/view appearance. It marks observation in
progress before pumping the run loop, so reentrant layout cannot install another observer.
The first callback satisfying the same conditions invalidates the display link and stops the
nested run loop. Three seconds is a failure deadline, not a settling delay. Missing hooks and
timeouts record a test issue instead of silently accepting an unprepared capture.

The existing spinner-freezing path keeps its original walk and does not wait for a mounted
frame unless explicitly requested. No shipping UI, baseline or image threshold changes.

## Validation

The controlled immediate/frame pair produces the failing/passing result above. The temporary
diagnostic is removed afterward. All 16 original image-comparison executions pass with zero
failures, skips or structured runtime warnings. All 192 existing sidebar executions, including
the frozen-spinner cases, also pass with zero failures, skips or structured runtime warnings.
An independent source review finds no actionable issue in the hook, opt-out path or ownership.

After Xcode component setup completes on 1 November, the full original iOS group 1 passes all
580 parameter executions across 64 functions on Xcode 27.2 and iOS 27.0, including every original
image comparison. Its coverage receipt completes. This is a local group result, not an aggregate
coverage verdict or a passing remote CI attempt.

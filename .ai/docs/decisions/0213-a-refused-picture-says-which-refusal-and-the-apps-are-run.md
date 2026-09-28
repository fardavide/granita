# A refused picture says which refusal, and the apps are run before a pull request

0.14.0 shipped image diffs and Davide's first read of one showed every frame saying *couldn't read
this picture*, with a `Try Again` that appeared to do nothing. Neither was an image-diff defect.

**The Mac was four minor versions behind the phone.** `/Applications/Granita.app` was 0.10.1 while
the phone had 0.14.0 from TestFlight; 0.10.1 serves no picture route, so every request answered 404.
The two halves ship separately — TestFlight for the phone, a notarised download for the Mac — so a
phone newer than its Mac is the ordinary state of this product between releases rather than an edge
case, and **nothing in the repository was wrong**. No gate could have seen it: the versions on the
machine are not something a check runs against.

**`Try Again` was working, and that was the second half of the defect.** It reset the frame,
re-asked a route that does not exist, failed instantly and returned to the same sentence — which
reads as inert, and moved the scroll slightly because the frame loses its button while it retries. A
control that cannot change the answer is the dead control this project treats as its worst defect,
arriving through a door nobody was watching.

### The frame owed a reason and did not give one

Design §9 already required a failed card to say **why**. The picture frame printed one sentence for
every failure, so *your Mac is asleep*, *git refused* and *your Mac is too old for this* were
indistinguishable — and the last of those is the only one whose remedy is not pressing a button.
`DiffImageRefusal` now maps each refusal to its own words, and `notUnderstood` — a 404 with no
refusal body, which is exactly what an older Mac answers on a route it has never had — says *your
Mac is too old to send pictures*. Where pressing cannot help, the button is **absent** rather than
disabled. The copy is in [design §4](../design.md).

### Running the apps is part of opening a pull request

Seven required checks were green on the release that shipped this, and the feature failed on the
first tap. Davide: *"Start the new app, and you should always do it when making a PR."* The rule is
in the `build-and-test` skill, with the two commands and the version check that would have found
this in seconds. **A green check is evidence the code compiles and renders; it is never evidence
anybody can use it**, which is the dead-control rule restated for the one case where both halves of
the product are involved and neither is at fault.

### A filtered build reports the filter's status

The same session read a failing snapshot suite as green four times, because the run was piped
through `grep | head` and the exit code belongs to the last segment. Bare runs found seven failing
suites, six of them order-dependent flakiness that passes on CI. The rule was already in the
`running-commands` skill and is now stated in terms of the consequence rather than of tidiness.


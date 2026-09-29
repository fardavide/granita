# The General tab re-reads the login item's status, because `register()` succeeding means very little

`SMAppService.register()` returns without throwing in the case that matters most: macOS accepts the
registration and then waits for the user to approve Granita in Login Items, leaving the status at
`.requiresApproval`. Nothing runs at the next login.

Reported as success — which is what a naive `try service.register()` does — the toggle shows on, the
reader believes the app will be there in the morning, and finds out it is not by rebooting and
watching their phone fail to find the Mac. For an app whose entire job is to be running when the
phone looks, that is the worst failure this tab can produce, and it is the *default* one.

So the registry re-reads its own status afterwards and reports anything that is not `.enabled` as not
registered, and the toggle has a third and fourth state rather than a boolean: waiting for approval,
and refused outright with the system's words. Both draw **off**, because a switch left on for a
registration that will not happen is the only reading on this tab that is actively false.

Rejected: putting the sentence in the `Data` layer by throwing a pre-worded refusal. The layer that
talks to `SMAppService` should say what happened, not how it reads.


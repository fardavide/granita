# A dead browser is replaced, and only a refusal that repeats is called one

iOS reports a refused local network permission as one of two DNS codes, and 0.0.3 taught the app to
read both as a refusal. That was half right. `PolicyDenied` (-65570) reaches a browser that is still
waiting and means what it says. `DefunctConnection` (-65569) only means the connection to
mDNSResponder is gone — and while that is what a browser created after a refusal sees, it is equally
what **every** browser sees when iOS suspends the app. So Granita accused Davide of a permission he
had granted, on a screen he reached by switching apps and coming back, and then stopped looking
because the stream ended with the accusation. Force-quitting was the only way out.

Decided: a browser is disposable and the session outlives it. A death is followed by a new browser
after a second, and `DefunctConnection` is only called a refusal once three replacements in a row
have died the same way — a refused browser dies as fast as one can be made, a suspended one does not
die again. `PolicyDenied` still means refusal on sight. Once refusal is the diagnosis the
replacements keep coming, five seconds apart, so granting the permission in Settings brings the Mac
back without relaunching.

The cost is about two seconds of "looking for your Mac" before a real refusal is named, bought
against a screen that lies to someone who changed nothing. The browser sits behind a protocol for
this reason and no other: the restart loop is otherwise reachable only by suspending an app on a
physical device, and it is the loop, not the mapping, that was broken.


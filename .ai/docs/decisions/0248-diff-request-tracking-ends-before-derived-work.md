# Diff request tracking ends before derived work

The Mac snapshot run on 26 October 2026 left all five reader files awaiting after a metadata
reload, and another render could not open an existing comment. A deterministic package regression
reproduces the awaiting state by suspending highlighting after the first diff has arrived, reloading
metadata and asking for the visible file again.

Diff request tracking covered highlighting and image loading as well as the repository request.
Reloading metadata replaces the entries with awaiting files, but the visible-file read skipped
those still tracked as in flight. Finishing the old highlighting pass cleared the tracking without
fetching the replacement entries.

The request's cleanup now runs after its repository result has been applied and before highlighting
or image loading suspends. Success, refusal and cancellation retain their cleanup paths. The lexical
scope also prevents an older highlighting pass from clearing a newer batch's tracking. The change
does not alter snapshot baselines, render delays or motion behavior.

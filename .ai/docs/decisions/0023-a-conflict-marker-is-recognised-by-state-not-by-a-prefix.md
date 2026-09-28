# A conflict marker is recognised by state, not by a prefix

A row of `=` signs is a Markdown heading underline far more often than it is a conflict separator, and
tagging one as a marker would render ordinary documentation as a conflict. So a separator or a
terminator only counts as one when an opener has been seen and not yet closed, and the marker must be
exactly seven characters, alone or followed by a label — nine equals signs is content.

Two consequences worth stating. The open-conflict state is held across the **whole file** rather than
reset per hunk, because a conflict region longer than twice the context breaks into two hunks and the
terminator then arrives in the second one. And `|||||||` is recognised alongside the three §4 names,
because the diff3 and zdiff3 conflict styles emit it and an agent's own git configuration may well
select one — a marker we do not recognise renders as content, which is the failure that matters here.


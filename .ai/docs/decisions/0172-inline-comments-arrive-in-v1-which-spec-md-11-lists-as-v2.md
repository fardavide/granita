# Inline comments arrive in v1, which `SPEC.md` §11 lists as v2

Davide asked for them on 3 September 2026: a comment on a run of changed lines, a button that
appears once there are any, one prompt for an overall note or a *Skip*, and the whole thing collected
into one piece of text he can copy and paste back to the agent that wrote the code.

`SPEC.md` §11 puts *"inline comments, line and range, with threads"* and *"feedback export"* in the
v2 backlog under **build none of them**, and §1 says v1 *"must not build v2"*. So this is a departure
rather than a slice, and it is recorded here rather than by editing the specification: the line §11
drew is what kept v1 finishable, and moving it quietly would lose the reason it was drawn.

**What is taken is narrower than what §11 describes, and deliberately.** No threads — a review is a
note left for an agent, not a conversation — and no `REVIEW.md`, no share sheet, no injection into a
live session. The known unknown §11 flags about `claude --resume` is untouched, because the
pasteboard is the reliable fallback that paragraph names and this builds only that.

**The architecture §11 asked for held.** Nothing on the wire changed, no route was added, the
contract version did not move, and the Mac does not know this feature exists. That is the *"design so
these stay cheap"* clause being cashed rather than a claim about it.


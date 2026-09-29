# Claude Design is asked with baselines and prose, and nothing is uploaded to it

Oltre's design loop is the model this borrows from, and its central part transfers unchanged: the
ask is a **round trip** rather than a hand-off, so the session that writes the prompt waits for the
frames and then builds them. The `design-handoff` skill carries that.

**Two parts do not transfer, and they are the decision.**

**The prompt is not a file here.** Oltre commits one per round trip under `.claude/prompts/`, as a
dated record of what was asked. Granita tried that and Davide rejected it the same day: *"You give
prompt in chat in code block, not in files. If we need to attach image, you place them on desktop."*
He is right about what the artefact is. A prompt is pasted once, into another tool, within the
minute — putting it behind a pull request puts a review gate in front of a clipboard, and on `main`
here that means four required checks. What is worth keeping is the **answer**, which this file and
the docs already have a home for. The cost accepted is that the exact wording of an ask is not
recoverable later; the calls it produced are, and those are what get re-read.

**And Oltre lifts its own colour tokens** into a Claude Design project so a frame is composed from
the same palette the app draws with.
Granita has no design-system module and will not grow one for v1 — the palette is semantic system
colours, the icons are SF Symbols, and every control on screen is a stock one. There is nothing to
upload, and uploading a synthesised stand-in would be worse than nothing: it would invite frames
built from a vocabulary the app does not have, and `swift-style` already forbids both the hardcoded
colour and the hand-rolled control that would be needed to build them. So the prompt names the
idiom instead, and asks for decisions inside it — hierarchy, what a row says, what an empty state
offers, which of two readings wins — rather than for a look.

**What goes over as the drawing is the committed snapshot corpus**, copied to the Desktop to be
attached, all four layouts of each state. The alternative considered was a hand-drawn mock, which
is faster and is an unchecked claim about what the app looks like; a baseline is the only image of
this app that something re-renders and compares. It is also why a screen built from a returned frame
lands with its baselines in the same pull request: they are what makes fidelity checkable later
rather than asserted once.

The cost is accepted and named: a surface with no snapshot suite — the Mac settings window, today —
can only be described, so what comes back for it is a first drawing rather than a review. Those two
kinds of ask are numbered separately inside a prompt rather than blurred together.


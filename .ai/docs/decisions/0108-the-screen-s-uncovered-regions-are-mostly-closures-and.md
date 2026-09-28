# The screen's uncovered regions are mostly closures, and "mostly" is the load-bearing word

The first read of the export said all of `GranitaSettingsScreen`'s uncovered regions were action
closures a render cannot invoke, and concluded the row was structurally unholdable by any pull
request adding a control. **That was wrong in a way worth recording, because it nearly bought a scope
change nobody needed.**

Two corrections. The count is **47 regions, not 29** — 29 is the number of distinct source lines they
sit on, and a line can carry several. And **four of the 47 are not closures at all**: they are the
`.sheet` presentation path — the builder, the `if let scan = model.folderScan` branch, its implicit
else, and the binding *read* evaluated during render. A snapshot handed a model with a folder scan
executes every one, which took the file from 47 uncovered to 43 and the row from 84.17% to 84.94%,
over the 84.65% baseline.

So the fix was a test for a real state — the window presenting design §4's sheet over Projects, which
no picture had ever executed, on the flow that is the security boundary. **The rescoping that the
first reading pointed at would have been the fifth reach for one and the second wrong one.**

**The remaining 43 are genuinely uncoverable by this project's current test kinds**, and that stands:
an action closure is invoked by a person, and only the `ui` kind has one. Adding controls to that
screen will keep pressing on this row until the Accessibility grant lets `make ui-tests-mac` run.

**The baseline is named for what it shows, not for what it exercises.** A hosted view presents a
sheet into a window of its own and the raster does not include it — the same limitation as the tab
bar — so the picture is `projects-beneath-the-scan-sheet`. Naming it for the sheet would be a picture
asserting the opposite of its own name, which that suite already refuses one paragraph above.


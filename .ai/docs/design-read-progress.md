# Read progress

Returned on 29 September 2026, second pass. The counter shows how much of a worktree's currently served change set the reader has explicitly marked viewed. A mark expires when the file's content hash changes, so progress can decrease after an agent edits a file.

## File selector

- Keep **Files** fixed above the list. After the first mark, put a small progress ring and **4 of 12 viewed** beside it, with secondary text and tabular digits. At completion, use the green `checkmark.circle.fill` and keep **12 of 12 viewed** in the same place.
- At zero, show only **Files**. The old **All 12 files viewed** footer goes away. Keep the truncation footer and count only the files the Mac served.
- The selector heading combines into one accessibility element; the arrangement menu stays separate. The review-comment count is unchanged.

## Diff view amendment — Davide, 29 September 2026

The first pass left the diff toolbar saying **12 files**, so a reader could not see the counter while reading the diff. Davide asked to show it there as well. The existing Files button now says **0 of 12 viewed**, **4 of 12 viewed**, or **12 of 12 viewed** from the moment the change set loads. It still opens the file selector, and VoiceOver names it as Files plus the progress. This replaces the returned call to leave **12 files** untouched: showing progress only inside the selector made it invisible until the reader opened the drawer. On a regular-width iPad with the selector column open, the column heading remains the visible counter; folding that column brings the progress button back.

## Worktree row

- Put a 12pt ring and **4 of 12** under the row's age. Show an empty ring and **0 of 12** before reading, an arc for partial progress, and the green filled check at completion. Draw a finished row's name in secondary colour without changing its order.
- Remove **12 files** from the second line when the fraction is present. A Mac that omits the optional count keeps the original second line and shows no progress mark.
- The ring is decorative. The row's spoken progress and Mac tooltip say **nothing viewed yet**, **4 of 12 files viewed**, or **all 12 files viewed**.

## Data and transitions

- The Mac counts marks that match the change set's current content hashes while constructing each worktree row. Project dirty counts remain independent of viewed marks.
- A mark updates the file heading and worktree row immediately. If the Mac refuses the write, both return to the previous count with the existing refusal alert. The next worktree-list read supplies the authoritative count.
- The worktree count is optional on decode so a newer client can still read an older Mac's list. Comments never count as viewed files.

import Foundation
import Testing

import CoreDiffDomain
import CoreReviewDomain

@testable import ClientViewerDomain

@Suite("Diff line input")
struct DiffLineInputTests {

    @Test
    func `given a measured unified hunk when a press begins on a row then that row is held and pressing is reported`() {
        // given
        var scenario = Scenario()
        var heldRows: [DiffLinePosition] = []
        var pressingChanges: [Bool] = []

        // when
        scenario.sut.began(
            at: CGPoint(x: 260, y: 109),
            targeting: scenario.targeting,
            onHold: { heldRows.append($0) },
            onPressingChanged: { pressingChanges.append($0) }
        )

        // then
        #expect(heldRows == [DiffLinePosition(oldNumber: 81, newNumber: 81)])
        #expect(pressingChanges == [true])
        #expect(scenario.sut.isPressing)
        #expect(scenario.sut.holds == 1)
    }

    @Test
    func `given idle input and a measured unified hunk when a row is tapped then that row is reported without holding`() {
        // given
        let scenario = Scenario()
        var tappedRows: [DiffLinePosition] = []

        // when
        scenario.sut.tapped(
            at: CGPoint(x: 260, y: 109),
            targeting: scenario.targeting,
            onTap: { tappedRows.append($0) }
        )

        // then
        #expect(tappedRows == [DiffLinePosition(oldNumber: 81, newNumber: 81)])
        #expect(scenario.sut.isPressing == false)
        #expect(scenario.sut.holds == 0)
    }

    @Test
    func `given a hold in the old split cell when dragging over the new cell then the original side stays selected`() {
        // given
        var scenario = Scenario(targeting: DiffLineTargeting(
            hunks: [
                Hunk(
                    index: 3, oldStart: 81, oldCount: 2, newStart: 91, newCount: 2,
                    sectionHeading: nil,
                    lines: [
                        DiffLine(
                            kind: .deletion, oldNumber: 81, newNumber: nil,
                            text: "let answer = 42", displayColumns: 15, segments: nil
                        ),
                        DiffLine(
                            kind: .deletion, oldNumber: 82, newNumber: nil,
                            text: "let question = 6 * 9", displayColumns: 20, segments: nil
                        ),
                        DiffLine(
                            kind: .addition, oldNumber: nil, newNumber: 91,
                            text: "let answer = 43", displayColumns: 15, segments: nil
                        ),
                        DiffLine(
                            kind: .addition, oldNumber: nil, newNumber: 92,
                            text: "let question = 7 * 9", displayColumns: 20, segments: nil
                        )
                    ]
                )
            ],
            frames: [3: CGRect(x: 0, y: 100, width: 1000, height: 36)],
            pointSize: 11,
            rowHeight: 18,
            isSplit: true,
            acceptsTargeting: true
        ))
        scenario.sut.began(
            at: CGPoint(x: 160, y: 109),
            targeting: scenario.targeting,
            onHold: { _ in },
            onPressingChanged: { _ in }
        )
        var draggedRows: [DiffLinePosition] = []

        // when
        scenario.sut.dragged(
            to: CGPoint(x: 800, y: 127),
            targeting: scenario.targeting,
            onDrag: { draggedRows.append($0) }
        )

        // then
        #expect(draggedRows == [DiffLinePosition(oldNumber: 82, newNumber: nil)])
    }

    @Test
    func `given a press is active when it finishes then pressing stops before the end is reported`() {
        // given
        enum Event: Equatable {
            case pressing(Bool)
            case ended
        }
        var scenario = Scenario()
        scenario.sut.began(
            at: CGPoint(x: 260, y: 109),
            targeting: scenario.targeting,
            onHold: { _ in },
            onPressingChanged: { _ in }
        )
        var events: [Event] = []

        // when
        scenario.sut.finished(
            onPressingChanged: { events.append(.pressing($0)) },
            onEnd: { events.append(.ended) }
        )

        // then
        #expect(events == [.pressing(false), .ended])
        #expect(scenario.sut.isPressing == false)
        #expect(scenario.sut.holds == 1)
    }

    @Test
    func `given a press is active when it is cancelled then pressing stops and the hold count stays`() {
        // given
        var scenario = Scenario()
        scenario.sut.began(
            at: CGPoint(x: 260, y: 109),
            targeting: scenario.targeting,
            onHold: { _ in },
            onPressingChanged: { _ in }
        )
        var pressingChanges: [Bool] = []

        // when
        scenario.sut.cancelled(onPressingChanged: { pressingChanges.append($0) })

        // then
        #expect(pressingChanges == [false])
        #expect(scenario.sut.isPressing == false)
        #expect(scenario.sut.holds == 1)
    }

    @Test(arguments: [
        (false, [3: CGRect(x: 0, y: 100, width: 400, height: 18)], CGPoint(x: 260, y: 109)),
        (true, [:], CGPoint(x: 260, y: 109)),
        (true, [3: CGRect(x: 0, y: 100, width: 400, height: 18)], CGPoint(x: 260, y: 150))
    ] as [(Bool, [Int: CGRect], CGPoint)])
    func `given targeting refuses a point when it is tapped then no row is reported`(
        acceptsTargeting: Bool,
        frames: [Int: CGRect],
        point: CGPoint
    ) {
        // given
        let scenario = Scenario(acceptsTargeting: acceptsTargeting, frames: frames)
        var tappedRows: [DiffLinePosition] = []

        // when
        scenario.sut.tapped(at: point, targeting: scenario.targeting, onTap: { tappedRows.append($0) })

        // then
        #expect(tappedRows.isEmpty)
        #expect(scenario.sut.isPressing == false)
        #expect(scenario.sut.holds == 0)
    }

    @Test(arguments: [
        (false, [3: CGRect(x: 0, y: 100, width: 400, height: 18)], CGPoint(x: 260, y: 109)),
        (true, [:], CGPoint(x: 260, y: 109)),
        (true, [3: CGRect(x: 0, y: 100, width: 400, height: 18)], CGPoint(x: 260, y: 150))
    ] as [(Bool, [Int: CGRect], CGPoint)])
    func `given targeting refuses a point when a press begins then no hold or pressing is reported`(
        acceptsTargeting: Bool,
        frames: [Int: CGRect],
        point: CGPoint
    ) {
        // given
        var scenario = Scenario(acceptsTargeting: acceptsTargeting, frames: frames)
        var heldRows: [DiffLinePosition] = []
        var pressingChanges: [Bool] = []

        // when
        scenario.sut.began(
            at: point,
            targeting: scenario.targeting,
            onHold: { heldRows.append($0) },
            onPressingChanged: { pressingChanges.append($0) }
        )

        // then
        #expect(heldRows.isEmpty)
        #expect(pressingChanges.isEmpty)
        #expect(scenario.sut.isPressing == false)
        #expect(scenario.sut.holds == 0)
    }

    @Test
    func `given targeting is disabled during a press when dragging then the selection is left alone`() {
        // given
        var scenario = Scenario()
        scenario.sut.began(
            at: CGPoint(x: 260, y: 109),
            targeting: scenario.targeting,
            onHold: { _ in },
            onPressingChanged: { _ in }
        )
        let disabledTargeting = Scenario(acceptsTargeting: false).targeting
        var draggedRows: [DiffLinePosition] = []

        // when
        scenario.sut.dragged(
            to: CGPoint(x: 260, y: 109),
            targeting: disabledTargeting,
            onDrag: { draggedRows.append($0) }
        )

        // then
        #expect(draggedRows.isEmpty)
        #expect(scenario.sut.isPressing)
        #expect(scenario.sut.holds == 1)
    }

    @Test
    func `given input is idle when dragging over a row then no drag is reported`() {
        // given
        let scenario = Scenario()
        var draggedRows: [DiffLinePosition] = []

        // when
        scenario.sut.dragged(
            to: CGPoint(x: 260, y: 109),
            targeting: scenario.targeting,
            onDrag: { draggedRows.append($0) }
        )

        // then
        #expect(draggedRows.isEmpty)
        #expect(scenario.sut.isPressing == false)
        #expect(scenario.sut.holds == 0)
    }

    @Test
    func `given input is idle when a press finishes then no pressing change or end is reported`() {
        // given
        var scenario = Scenario()
        var pressingChanges: [Bool] = []
        var endings = 0

        // when
        scenario.sut.finished(
            onPressingChanged: { pressingChanges.append($0) },
            onEnd: { endings += 1 }
        )

        // then
        #expect(pressingChanges.isEmpty)
        #expect(endings == 0)
        #expect(scenario.sut.isPressing == false)
        #expect(scenario.sut.holds == 0)
    }

    @Test
    func `given input is idle when a press is cancelled then no pressing change is reported`() {
        // given
        var scenario = Scenario()
        var pressingChanges: [Bool] = []

        // when
        scenario.sut.cancelled(onPressingChanged: { pressingChanges.append($0) })

        // then
        #expect(pressingChanges.isEmpty)
        #expect(scenario.sut.isPressing == false)
        #expect(scenario.sut.holds == 0)
    }

    @Test
    func `given a press is active when a row is tapped then the tap is suppressed`() {
        // given
        var scenario = Scenario()
        scenario.sut.began(
            at: CGPoint(x: 260, y: 109),
            targeting: scenario.targeting,
            onHold: { _ in },
            onPressingChanged: { _ in }
        )
        var tappedRows: [DiffLinePosition] = []

        // when
        scenario.sut.tapped(
            at: CGPoint(x: 260, y: 109),
            targeting: scenario.targeting,
            onTap: { tappedRows.append($0) }
        )

        // then
        #expect(tappedRows.isEmpty)
        #expect(scenario.sut.isPressing)
        #expect(scenario.sut.holds == 1)
    }

    @Test
    func `given a press in one hunk when dragging across a gap then targeting resumes in the next measured hunk`() {
        // given
        var scenario = Scenario(targeting: DiffLineTargeting(
            hunks: [
                Hunk(
                    index: 3, oldStart: 81, oldCount: 1, newStart: 81, newCount: 1,
                    sectionHeading: nil,
                    lines: [
                        DiffLine(
                            kind: .context, oldNumber: 81, newNumber: 81,
                            text: "let answer = 42", displayColumns: 15, segments: nil
                        )
                    ]
                ),
                Hunk(
                    index: 4, oldStart: 91, oldCount: 1, newStart: 91, newCount: 1,
                    sectionHeading: nil,
                    lines: [
                        DiffLine(
                            kind: .context, oldNumber: 91, newNumber: 91,
                            text: "let question = 6 * 9", displayColumns: 20, segments: nil
                        )
                    ]
                )
            ],
            frames: [
                3: CGRect(x: 0, y: 100, width: 400, height: 18),
                4: CGRect(x: 0, y: 180, width: 400, height: 18)
            ],
            pointSize: 11,
            rowHeight: 18,
            isSplit: false,
            acceptsTargeting: true
        ))
        scenario.sut.began(
            at: CGPoint(x: 260, y: 109),
            targeting: scenario.targeting,
            onHold: { _ in },
            onPressingChanged: { _ in }
        )
        var draggedRows: [DiffLinePosition] = []

        // when
        scenario.sut.dragged(
            to: CGPoint(x: 260, y: 150),
            targeting: scenario.targeting,
            onDrag: { draggedRows.append($0) }
        )
        scenario.sut.dragged(
            to: CGPoint(x: 260, y: 189),
            targeting: scenario.targeting,
            onDrag: { draggedRows.append($0) }
        )

        // then
        #expect(draggedRows == [DiffLinePosition(oldNumber: 91, newNumber: 91)])
        #expect(scenario.sut.isPressing)
        #expect(scenario.sut.holds == 1)
    }

    @Test
    func `given split mode and a narrow measured hunk when a row is targeted then unified targeting answers`() {
        // given
        let scenario = Scenario(isSplit: true, frames: [3: CGRect(x: 0, y: 100, width: 100, height: 18)])

        // when
        let line = scenario.targeting.line(at: CGPoint(x: 80, y: 109))

        // then
        #expect(line == DiffLinePosition(oldNumber: 81, newNumber: 81))
    }

    @Test(arguments: [
        (DiffLineKind.deletion, 81, nil, CGFloat(160), DiffLinePosition(oldNumber: 81, newNumber: nil)),
        (.addition, nil, 91, CGFloat(800), DiffLinePosition(oldNumber: nil, newNumber: 91)),
        (.noNewlineMarker, nil, nil, CGFloat(160), nil)
    ] as [(DiffLineKind, Int?, Int?, CGFloat, DiffLinePosition?)])
    func `given a hunk with only one numbered side when targeting then that side answers and numberless rows refuse`(
        kind: DiffLineKind,
        oldNumber: Int?,
        newNumber: Int?,
        x: CGFloat,
        expected: DiffLinePosition?
    ) {
        // given
        let scenario = Scenario(targeting: DiffLineTargeting(
            hunks: [
                Hunk(
                    index: 3, oldStart: 81, oldCount: 1, newStart: 91, newCount: 1,
                    sectionHeading: nil,
                    lines: [
                        DiffLine(
                            kind: kind, oldNumber: oldNumber, newNumber: newNumber,
                            text: "let answer = 42", displayColumns: 15, segments: nil
                        )
                    ]
                )
            ],
            frames: [3: CGRect(x: 0, y: 100, width: 1000, height: 18)],
            pointSize: 11,
            rowHeight: 18,
            isSplit: true,
            acceptsTargeting: true
        ))

        // when
        let line = scenario.targeting.line(at: CGPoint(x: x, y: 109))

        // then
        #expect(line == expected)
    }

    private struct Scenario {
        var sut = DiffLineInput()
        let targeting: DiffLineTargeting

        init(
            acceptsTargeting: Bool = true,
            isSplit: Bool = false,
            frames: [Int: CGRect] = [3: CGRect(x: 0, y: 100, width: 400, height: 18)]
        ) {
            targeting = DiffLineTargeting(
                hunks: [
                    Hunk(
                        index: 3, oldStart: 81, oldCount: 1, newStart: 81, newCount: 1,
                        sectionHeading: nil,
                        lines: [
                            DiffLine(
                                kind: .context, oldNumber: 81, newNumber: 81,
                                text: "let answer = 42", displayColumns: 15, segments: nil
                            )
                        ]
                    )
                ],
                frames: frames,
                pointSize: 11,
                rowHeight: 18,
                isSplit: isSplit,
                acceptsTargeting: acceptsTargeting
            )
        }

        init(targeting: DiffLineTargeting) {
            self.targeting = targeting
        }
    }
}

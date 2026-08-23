import Foundation
import Synchronization
import Testing

import ServerApiDomain
import ServerApiPresentation

/// SPEC §9's connection log, which is what makes a phone that will not connect debuggable without
/// attaching a debugger. Everything asserted here is read three rooms away from the Mac.
@Suite("In-memory connection log")
struct InMemoryConnectionLogTests {

    @Test
    func `given a refusal when it is recorded then the log reads back its reason and its source`() async {
        // given
        let log = InMemoryConnectionLog(now: { Date(timeIntervalSince1970: 1_000) })

        // when
        await log.record(source: "192.168.1.24", outcome: .refused(.unknownToken))

        // then
        let attempts = await firstReading(of: log)
        #expect(attempts.count == 1)
        #expect(attempts.first?.source == "192.168.1.24")
        #expect(attempts.first?.outcome == .refused(.unknownToken))
        #expect(attempts.first?.at == Date(timeIntervalSince1970: 1_000))
    }

    @Test
    func `given more attempts than the panel shows when they are recorded then the oldest fall off`() async {
        // given — a phone retrying every second fills fifty in under a minute, and the fifty that
        // matter are the recent ones.
        let log = InMemoryConnectionLog(now: { Date(timeIntervalSince1970: 1_000) })

        // when
        for index in 1...51 {
            await log.record(source: "phone-\(index)", outcome: .refused(.noToken))
        }

        // then
        let attempts = await firstReading(of: log)
        #expect(attempts.count == 50)
        #expect(attempts.first?.source == "phone-51")
        #expect(attempts.last?.source == "phone-2")
        #expect(attempts.contains { $0.source == "phone-1" } == false)
    }

    @Test
    func `given a phone polling when it is served each time then the panel keeps one row for it`() async {
        // given — a phone re-reads a worktree every couple of seconds. Fifty of those would push
        // off the one refusal that explains why the *other* phone cannot get in, which is the
        // question the panel exists to answer.
        let log = InMemoryConnectionLog(now: { Date(timeIntervalSince1970: 1_000) })
        await log.record(source: "192.168.1.9", outcome: .refused(.unknownToken))

        // when
        for _ in 1...10 {
            await log.record(source: "192.168.1.24", outcome: .accepted(device: "Davide's iPhone"))
        }

        // then
        let attempts = await firstReading(of: log)
        #expect(attempts.count == 2)
        #expect(attempts.first?.outcome == .accepted(device: "Davide's iPhone"))
        #expect(attempts.last?.outcome == .refused(.unknownToken))
    }

    @Test
    func `given a phone that keeps being served when the panel is read then its row says when it last got in`() async {
        // given — a row frozen at the first success answers "did this phone ever connect", which is
        // not the question anyone asks while looking at a phone that has stopped updating.
        let ticks = Mutex<TimeInterval>(0)
        let log = InMemoryConnectionLog(now: {
            ticks.withLock { seconds in
                seconds += 60
                return Date(timeIntervalSince1970: seconds)
            }
        })

        // when
        await log.record(source: "192.168.1.24", outcome: .accepted(device: "Davide's iPhone"))
        await log.record(source: "192.168.1.24", outcome: .accepted(device: "Davide's iPhone"))

        // then
        let attempts = await firstReading(of: log)
        #expect(attempts.count == 1)
        #expect(attempts.first?.at == Date(timeIntervalSince1970: 120))
    }

    @Test
    func `given the same refusal over and over when the panel is read then its row counts them`() async {
        // given — coalescing is right and, on its own, turns four hundred attempts into a row that
        // looks like one. "My phone tried once" and "my phone has been hammering this for ten
        // minutes" are different problems and this is the only place they are told apart.
        let log = InMemoryConnectionLog(now: { Date(timeIntervalSince1970: 1_000) })

        // when
        for _ in 1...412 {
            await log.record(source: "192.168.1.42", outcome: .refused(.noToken))
        }

        // then
        let attempts = await firstReading(of: log)
        #expect(attempts.count == 1)
        #expect(attempts.first?.occurrences == 412)
    }

    @Test
    func `given a panel that was closed when another opens then it reads everything recorded since`() async {
        // given — a reader that has gone away, which is what closing the Settings window leaves
        // behind. It is dropped on the next write rather than announcing its own departure: the
        // arrangement that did announce it hopped through a detached task, so whether the removal
        // ran at all was a race, and the only thing that ever noticed was a coverage row moving on
        // one machine and not another.
        let log = InMemoryConnectionLog(now: { Date(timeIntervalSince1970: 1_000) })
        do {
            _ = await log.attempts()
        }

        // when
        await log.record(source: "192.168.1.42", outcome: .refused(.noToken))
        await log.record(source: "192.168.1.7", outcome: .accepted(device: "Davide's iPhone"))

        // then — the panel that opens next is whole, which is the behaviour the pruning must not
        // cost. A reader removed while it was still being written to would lose an attempt.
        let attempts = await firstReading(of: log)
        #expect(attempts.count == 2)
        #expect(attempts.first?.source == "192.168.1.7")
    }

    @Test
    func `given one attempt when the panel is read then its row counts one`() async {
        // given
        let log = InMemoryConnectionLog(now: { Date(timeIntervalSince1970: 1_000) })

        // when
        await log.record(source: "192.168.1.42", outcome: .refused(.noToken))

        // then
        let attempts = await firstReading(of: log)
        #expect(attempts.first?.occurrences == 1)
    }

    @Test
    func `given a device that stops repeating itself when it comes back then its count starts again`() async {
        // given — the count belongs to the row, and a row is one uninterrupted run of the same thing
        // from the same place. Carrying a total across a row that fell in between would report a
        // number no visible row accounts for.
        let log = InMemoryConnectionLog(now: { Date(timeIntervalSince1970: 1_000) })
        await log.record(source: "192.168.1.42", outcome: .refused(.noToken))
        await log.record(source: "192.168.1.42", outcome: .refused(.noToken))

        // when
        await log.record(source: "192.168.1.57", outcome: .refused(.unknownToken))
        await log.record(source: "192.168.1.42", outcome: .refused(.noToken))

        // then
        let attempts = await firstReading(of: log)
        #expect(attempts.map(\.occurrences) == [1, 1, 2])
    }

    // Time-limited because the failure mode is a wait rather than a wrong value: a log that stops
    // telling its readers anything leaves this test waiting for a reading that never arrives, and a
    // suite that hangs says less than one that goes red.
    @Test(.timeLimit(.minutes(1)))
    func `given the panel is open when an attempt happens then the reader is sent it unasked`() async {
        // given — the panel is opened *because* a phone is failing, so the attempt worth seeing is
        // the one that has not happened yet.
        let log = InMemoryConnectionLog(now: { Date(timeIntervalSince1970: 1_000) })
        var readings = await log.attempts().makeAsyncIterator()
        _ = await readings.next()

        // when
        await log.record(source: "192.168.1.24", outcome: .accepted(device: "Davide's iPhone"))

        // then
        let reading = await readings.next()
        #expect(reading?.first?.outcome == .accepted(device: "Davide's iPhone"))
    }
}

// MARK: -

/// What the log holds now. The log reports itself as a stream because the panel is watched while a
/// phone is failing to connect, so the first element of that stream is its current contents.
private func firstReading(of log: InMemoryConnectionLog) async -> [ConnectionAttempt] {
    var readings = await log.attempts().makeAsyncIterator()
    return await readings.next() ?? []
}

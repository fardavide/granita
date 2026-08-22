import Testing

import ServerApiDomain

@testable import ServerApiPresentation

@Suite("Rebinds")
struct RebindsTests {

    @Test
    func `given the Mac wakes when the server is following rebinds then it is asked to stand up again`() async {
        // given
        let wakes = FakeWakeNotifications()
        let sut = Rebinds(wakes: wakes)
        var rebinds = sut.wakes().makeAsyncIterator()

        // when
        wakes.wake()

        // then
        await #expect(rebinds.next() != nil)
    }

    @Test
    func `given the reader presses Restart when nothing has woken then the server is asked to stand up again`() async {
        // given — the same rebind, from the other source. Restart exists because a wake is not the
        // only way to lose a bind: a laptop that changed network keeps running and stops being
        // reachable, and there is no notification for that.
        let sut = Rebinds(wakes: FakeWakeNotifications())
        var rebinds = sut.wakes().makeAsyncIterator()

        // when
        await sut.restart()

        // then
        await #expect(rebinds.next() != nil)
    }

    @Test
    func `given both sources when each fires once then the server is asked twice`() async {
        // given — one stream, two sources, and neither may swallow the other: a Restart pressed
        // just after waking is a person saying the wake did not work.
        let wakes = FakeWakeNotifications()
        let sut = Rebinds(wakes: wakes)
        var rebinds = sut.wakes().makeAsyncIterator()

        // when
        wakes.wake()
        await rebinds.next()
        await sut.restart()

        // then
        await #expect(rebinds.next() != nil)
    }
}

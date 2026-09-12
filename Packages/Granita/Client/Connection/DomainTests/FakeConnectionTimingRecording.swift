import ClientConnectionDomain

actor FakeConnectionTimingRecording: ConnectionTimingRecording {
    private(set) var events: [ConnectionTimingEvent] = []

    func record(_ event: ConnectionTimingEvent) {
        events.append(event)
    }
}

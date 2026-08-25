import AVFoundation
import Testing

import ClientConnectionDomain
@testable import ClientConnectionData

/// A camera grant is one of four things and design §5 draws a different screen for each, so the
/// mapping is the whole of what this file decides — the two calls around it are a line each, and
/// neither of them can be made here: one reads a grant recorded against a signed app, the other puts
/// an alert in front of somebody in the room.
@Suite("Capture device camera authorization")
struct CaptureDeviceCameraAuthorizationTests {

    @Test
    func `given the reader has not been asked yet when the status is read then the alert has somewhere to land`() {
        // when - then — design §5's first camera state, and the one usually left undrawn: the alert
        // is modal over a screen, and this is the screen the reader is reading while they decide.
        #expect(CaptureDeviceCameraAuthorization.access(for: .notDetermined) == .notAsked)
    }

    @Test
    func `given the reader allowed the camera when the status is read then the viewfinder may open`() {
        // when - then
        #expect(CaptureDeviceCameraAuthorization.access(for: .authorized) == .granted)
    }

    @Test
    func `given the reader declined when the status is read then it is a refusal rather than a fault`() {
        // when - then — nothing has gone wrong, which is why this is a case of its own rather than an
        // error: the six words are the remedy and they were always going to be there.
        #expect(CaptureDeviceCameraAuthorization.access(for: .denied) == .refused)
    }

    @Test
    func `given a policy holds the camera shut when the status is read then it was not the reader who refused`() {
        // when - then — the case that earns its own name. *Turn the Camera On in Settings* is the one
        // control design §5 puts under a refusal, and under a restriction there is no switch behind
        // it: folded into `refused` this would ship a button that does nothing.
        #expect(CaptureDeviceCameraAuthorization.access(for: .restricted) == .restricted)
    }

    @Test
    func `given a status this app has never heard of when it is read then nothing is read as a grant`() {
        // given — `AVAuthorizationStatus` is an Objective-C enumeration and is not frozen, so a
        // system newer than this build can answer with something not on the list. Built from a raw
        // value, which is the only way one of those exists on this machine — and the reason the
        // browse next door leaves its own unknown branch unreached is that `NWError` offers no such
        // door.
        let unknown = AVAuthorizationStatus(rawValue: 99)

        // when — mapped rather than unwrapped: the initialiser is optional and this raw value is not
        // one it refuses, so a `nil` would be a fact about the import worth failing on rather than
        // one to force past.
        let access = unknown.map(CaptureDeviceCameraAuthorization.access(for:))

        // then — refused *and* not the reader's doing, which is the only pair of answers that is
        // safe in both directions: the camera stays shut, and nobody is sent to Settings to look for
        // a switch that may not be the one holding it.
        #expect(access == .restricted)
    }

    // MARK: - The part a real device answers

    @Test
    func `given the real device when it is asked what it already knows then it says so without asking anybody`() {
        // given — the one call in this type a test process may make. Reading a status is not itself
        // a privacy-checked act; opening a camera and requesting access both are, which is why
        // neither appears below and why this type exists behind a protocol at all.
        let sut = CaptureDeviceCameraAuthorization()

        // when
        let first = sut.current
        let second = sut.current

        // then — that the two agree is the assertion, and it is the promise the screen leans on:
        // `current` is a question rather than a prompt, so reading it on the way in cannot be what
        // puts the alert on screen. A second answer that differed would mean it had been.
        #expect(first == second)
    }
}

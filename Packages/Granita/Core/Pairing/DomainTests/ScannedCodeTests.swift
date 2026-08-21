import Foundation
import Testing

import CorePairingDomain

/// What a camera hands the app, and which of those things are worth telling the reader about.
///
/// **A viewfinder is not a form.** A form is submitted once and every refusal is news; a scanner
/// reads whatever is in front of it, several times a second, and most of what it finds is a Wi-Fi
/// code on a poster or a URL on the back of a bus. Reporting those as errors would put a stream of
/// refusals in front of somebody who is simply holding a phone up at a screen.
///
/// So the distinction this draws is not valid/invalid. It is **ours/not ours**: a `granita://` link
/// that is damaged is worth a sentence, because the reader is pointing at the right thing and it is
/// not working. Anything else is not an event at all.
struct ScannedCodeTests {

    // MARK: - The one we want

    @Test func `given a whole pairing link when it is scanned then it is one to act on`() {
        // given
        let text = "granita://pair?host=macbook-pro.local&port=59144&code=abc123&spki=I5uJIP2x"

        // when
        let outcome = PairingLink.scanned(text)

        // then
        #expect(outcome == .pairingLink(PairingLink(
            host: "macbook-pro.local",
            port: 59144,
            code: "abc123",
            fingerprint: SpkiFingerprint(rawValue: "I5uJIP2x")
        )))
    }

    // MARK: - Not ours, and therefore not news

    @Test func `given a web address when it is scanned then it is passed over in silence`() {
        // given
        let text = "https://example.com/some-poster"

        // when
        let outcome = PairingLink.scanned(text)

        // then
        #expect(outcome == .somethingElse)
    }

    @Test func `given a wifi code when it is scanned then it is passed over in silence`() {
        // given
        // The single most likely thing to be in shot beside a Mac at a desk.
        let text = "WIFI:S:Davide's Network;T:WPA;P:hunter2;;"

        // when
        let outcome = PairingLink.scanned(text)

        // then
        #expect(outcome == .somethingElse)
    }

    @Test func `given text that is not a url at all when it is scanned then it is passed over in silence`() {
        // given
        let text = "just some words on a sticker"

        // when
        let outcome = PairingLink.scanned(text)

        // then
        // A scanned string need not be a URL, so this must not depend on `URL(string:)` refusing it
        // — on Apple platforms that initialiser accepts a great deal of ordinary text.
        #expect(outcome == .somethingElse)
    }

    @Test func `given an empty scan when it is read then it is passed over in silence`() {
        // given - when
        let outcome = PairingLink.scanned("")

        // then
        #expect(outcome == .somethingElse)
    }

    @Test func `given another app's scheme when it is scanned then it is passed over in silence`() {
        // given
        let text = "othertool://pair?host=macbook-pro.local&port=59144&code=abc&spki=xyz"

        // when
        let outcome = PairingLink.scanned(text)

        // then
        #expect(outcome == .somethingElse)
    }

    @Test func `given our scheme asking for something other than pairing when it is scanned then it is passed over in silence`() {
        // given
        let text = "granita://open?worktree=abc"

        // when
        let outcome = PairingLink.scanned(text)

        // then
        // Ours, but not this screen's business. A future action must not surface here as damage.
        #expect(outcome == .somethingElse)
    }

    // MARK: - Ours, and broken, which is worth a sentence

    @Test func `given our pairing link with a field missing when it is scanned then it is reported as damaged`() {
        // given
        let text = "granita://pair?host=macbook-pro.local&port=59144&code=abc123"

        // when
        let outcome = PairingLink.scanned(text)

        // then
        // The reader is pointing at the right screen and it is not working. Silence here would look
        // like a camera that had stopped.
        #expect(outcome == .damagedPairingLink(.missingField(named: "spki")))
    }

    @Test func `given our pairing link with a port that is not a number when it is scanned then it is reported as damaged`() {
        // given
        let text = "granita://pair?host=macbook-pro.local&port=fifty&code=abc123&spki=I5uJIP2x"

        // when
        let outcome = PairingLink.scanned(text)

        // then
        #expect(outcome == .damagedPairingLink(.malformedField(named: "port")))
    }
}

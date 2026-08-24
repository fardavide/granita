import ServerApiDomain
import SwiftUI

/// The menu behind the status item. Stateless: it renders what it is handed and reports what was
/// chosen, so the composition root above it owns the server and this owns none of it.
///
/// Design §1. Under `LSUIElement` this menu is the entire app when Settings is shut, which is what
/// earns each of the rows below its place — a person holding a phone and looking for the QR has
/// nowhere else to look, and a person whose Mac is not serving has nowhere else to be told.
public struct MenuBarContent: View {

    private let state: ServerRunState
    private let onCopyAddress: () -> Void
    private let onPairDevice: () -> Void
    private let onOpenLocalNetworkSettings: () -> Void
    private let onOpenSettings: () -> Void
    private let onQuit: () -> Void

    public init(
        state: ServerRunState,
        onCopyAddress: @escaping () -> Void,
        onPairDevice: @escaping () -> Void,
        onOpenLocalNetworkSettings: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.state = state
        self.onCopyAddress = onCopyAddress
        self.onPairDevice = onPairDevice
        self.onOpenLocalNetworkSettings = onOpenLocalNetworkSettings
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
    }

    public var body: some View {
        status

        Divider()

        // A second door to the one QR in the app, not a second implementation of it. Disabled
        // rather than absent when there is nothing to encode: a row that vanishes leaves a reader
        // looking for it, while a greyed one directly under *Not serving* has already said why.
        Button("Pair a device…", action: onPairDevice)
            .disabled(canPair == false)

        Button("Settings…", action: onOpenSettings)
            .keyboardShortcut(",")

        Divider()

        Button("Quit Granita", action: onQuit)
            .keyboardShortcut("q")
    }

    /// Everything below is decided by whether the server is running, so it is one switch rather than
    /// a condition per row.
    ///
    /// **The status line is a `Button` that copies**, and it was a `Text` the code itself called
    /// "present, legible and unclickable". The port is different on every launch — 59144, 59145,
    /// 53613, 53611 across four recorded runs — so nobody memorises it and the only reason to read
    /// it is to paste it somewhere.
    ///
    /// **What it copies has no scheme**, which is this pull request's call rather than the drawing's:
    /// the frames show `http://`, and the Mac has served TLS under a self-signed identity since
    /// 0.0.7. `https://` pasted into a browser produces a certificate warning instead of an answer,
    /// and General had already settled on host and port alone — two rows copying one fact must not
    /// spell it two ways.
    ///
    /// **The copy is announced before it happens.** A menu closes on click, so a row whose whole
    /// effect is a changed pasteboard has no way to report itself afterwards; the symbol is General's
    /// own, so the affordance a reader has already met there means the same thing here.
    @ViewBuilder private var status: some View {
        switch state {
        case .starting:
            Text("Starting…")
        case .running(let endpoint):
            // Built as a Swift string rather than interpolated into the label, because a
            // `LocalizedStringKey` formats an `Int` under the reader's locale and would draw the
            // port as 59,144.
            let address = "\(endpoint.host):\(endpoint.port)"
            Button(action: onCopyAddress) {
                Label {
                    Text(verbatim: "Serving on \(address)")
                } icon: {
                    Image(systemName: "doc.on.doc")
                }
            }
        case .failed:
            // The refusal, and the one thing to do about it. **Not the reason**: `failed` carries
            // whatever went wrong, a locked keychain reaches it too, and a menu has no room for the
            // small print that lets General name a likely cause without asserting it. §1 says the
            // reason is one click below, and *Settings…* is that click.
            Text("Not serving")
            Button("Open Local Network Settings…", action: onOpenLocalNetworkSettings)
        case .stopped:
            // No button. Local Network is the overwhelmingly common way the state above is reached
            // and it is no way at all to reach this one — the server's life is the app's life, so
            // stopped means it fell over.
            Text("Not serving")
        case .blockedByAnotherProcess(let holder):
            // Named here rather than left to Settings, unlike `failed` above. The difference is
            // that this reason is one short noun and it is the whole of what a reader has to act
            // on — there is no small print to leave out and no likely cause to hedge, because the
            // lock is a fact rather than a guess.
            Text(verbatim: "Not serving — \(holder?.sentence ?? "another process") has the settings")
        }
    }

    /// `.starting` pairs, and that is a departure from design §1's "disabled when the server is not
    /// running".
    ///
    /// A bind takes a moment and a rebind after waking takes longer, and the Devices pane already has
    /// a drawn state for exactly that moment — a code being made. Disabling a row for a state that
    /// resolves itself in under a second would fight a reader who is standing there with a phone,
    /// and it is the same call the pane below already makes about the same moment.
    private var canPair: Bool {
        switch state {
        case .starting, .running: true
        // A blocked lock is the one refusal that will not resolve itself by waiting, so unlike
        // `.starting` there is nothing here for a reader with a phone in their hand to wait for.
        case .failed, .stopped, .blockedByAnotherProcess: false
        }
    }
}

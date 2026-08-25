import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Opens this app's page in Settings.
///
/// Three screens offer it — a browse the local network refused, a camera the reader turned off, and
/// six words that could not resolve because of the first — and they are three renderings of one act,
/// so it is written once rather than three times over.
///
/// Not behind a seam, unlike everything else in this unit that touches the outside: it hands a URL
/// the system owns to the system and is told nothing back, so there is no answer for a screen to
/// branch on and nothing for a fake to stand in for.
func openSettings() {
    #if canImport(UIKit)
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    UIApplication.shared.open(url)
    #endif
}

import ServerMacUi
import SwiftUI

/// Granita's Settings window.
///
/// SPEC §9 gives it four tabs — General, Projects, Devices, Advanced. Advanced is here first
/// because the connection log is the one panel that is useful before anything else works: the rest
/// of the window is about setting Granita up, and this is about finding out why the setup is not
/// taking.
public struct GranitaSettingsScreen: View {

    private let model: ServerMacModel

    public init(model: ServerMacModel) {
        self.model = model
    }

    public var body: some View {
        TabView {
            Tab("Advanced", systemImage: "gearshape.2") {
                ConnectionLogView(attempts: model.connectionAttempts)
                    .task { await model.followConnections() }
            }
        }
        // A minimum rather than a fixed size, so the three tabs SPEC §9 still owes this window can
        // each be taller without any of them being narrower.
        .frame(minWidth: 560, minHeight: 400)
    }
}

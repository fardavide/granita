import SwiftUI

import ClientConnectionDomain
import ClientConnectionUi

public struct MacWordsPairingScreen: View {
    @Bindable private var model: ClientConnectionModel
    private let server: DiscoveredServer
    private let device: PairingDevice
    private let onPaired: (PairedMac) -> Void
    @Environment(\.dismiss) private var dismiss

    public init(
        model: ClientConnectionModel,
        server: DiscoveredServer,
        device: PairingDevice,
        onPaired: @escaping (PairedMac) -> Void
    ) {
        self.model = model
        self.server = server
        self.device = device
        self.onPaired = onPaired
    }

    public var body: some View {
        VStack {
            HStack {
                Text("Pair with \(server.name)").font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .disabled(model.pairing == .spending || model.pairing == .savingToken)
            }
            .padding()
            if model.pairing == .notStarted {
                PairingWordsView(
                    macName: server.name,
                    typedWords: $model.typedWords,
                    spokenWords: model.spokenWords,
                    unknownWord: model.firstUnknownWord,
                    onPair: {
                        Task { await model.spendTypedWords(on: server, as: device) }
                    }
                )
            } else {
                PairingOutcomeView(
                    macName: server.name,
                    state: model.pairing,
                    logCopyState: model.logCopyState,
                    canOpenTestFlight: false,
                    onTryAgain: { Task { await model.spendAgain(on: server, as: device) } },
                    onSaveTokenAgain: { Task { await model.saveTokenAgain() } },
                    onOpenTestFlight: {},
                    onOpenSettings: { model.openSettings(.localNetwork) },
                    onCopyLogs: { Task { await model.copyLogs(context: .pairing(model.pairing)) } }
                )
                Button("Enter another code") { model.beginPairing(with: server) }
                    .disabled(model.pairing == .spending || model.pairing == .savingToken)
            }
        }
        .frame(width: 440, height: 460)
        .handsOverAPairedMac(from: model.pairing, to: onPaired)
    }
}

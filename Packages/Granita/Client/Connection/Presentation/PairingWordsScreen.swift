import SwiftUI

import ClientConnectionDomain
import ClientConnectionUi

/// The field, bound to the phrase the model reads and to the stack it pushes onto.
///
/// **The outcome is pushed here rather than swapped in**, which is the opposite of what the
/// viewfinder does one file over, and the difference is what a reader comes back to: there is no
/// countdown on this phone, so a refusal has to arrive as a consequence — the screen keeps what was
/// typed and the reader is one back tap from a phrase they can send at a fresh code. A viewfinder
/// has nothing to keep.
struct PairingWordsScreen: View {

    @Bindable private var model: ClientConnectionModel

    private let server: DiscoveredServer
    private let phone: ThisPhone

    @Binding private var path: NavigationPath

    init(
        model: ClientConnectionModel,
        server: DiscoveredServer,
        phone: ThisPhone,
        path: Binding<NavigationPath>
    ) {
        _model = Bindable(model)
        self.server = server
        self.phone = phone
        _path = path
    }

    var body: some View {
        PairingWordsView(
            macName: server.name,
            typedWords: $model.typedWords,
            spokenWords: model.spokenWords,
            unknownWord: model.firstUnknownWord,
            onPair: pair
        )
    }

    /// Spends the phrase, and shows the reader that something is happening while it is spent.
    ///
    /// The guard is the keyboard's Go key rather than the button: the button is dark below six
    /// words, and Go submits whatever is in the field. The model refuses a short phrase either way,
    /// so what this stops is a receipt pushed for an attempt that was never made — a spinner over a
    /// screen the reader can no longer type into.
    private func pair() {
        guard model.isCodeComplete else { return }
        path.append(PairingStep.theOutcome)
        Task { await model.spendTypedWords(on: server, as: phone.device) }
    }
}

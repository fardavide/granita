import Foundation

/// Composition root for the terminal. The menu bar app embeds the same backend in-process; this
/// executable is what makes it build, run and test with `swift run` and `swift test`, with no
/// Xcode in the loop — and what recovers a review session when the UI is the thing that is broken.
@main
struct GranitaServer {

    static func main() async {
        FileHandle.standardError.write(Data("granita-server: no server yet — milestone M2\n".utf8))
    }
}

import ServerMacDomain

/// Which git is installed, without running one.
struct FakeGitInstallations: GitInstallations {

    let installation: GitInstallation

    func current() async -> GitInstallation {
        installation
    }
}

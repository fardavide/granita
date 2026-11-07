import Testing

import CoreDiffDomain
import ServerGitDomain
@testable import ServerWorktreesDomain

@Suite("Worktree observation routing")
struct WorktreeObservationTopologyTests {

    @Test
    func `given a linked worktree nested in another when its file changes then only the linked worktree refreshes`() {
        // given
        let scenario = Scenario()

        // when
        let reaction = scenario.sut.reaction(to: .changed([
            RepositoryLocation(path: "/project/.claude/worktrees/agent/Sources/Reader.swift")
        ]))

        // then
        #expect(reaction == .refresh([WorktreeID(canonicalPath: "/project/.claude/worktrees/agent")]))
    }

    @Test
    func `given a linked worktree index when it changes then only that worktree refreshes`() {
        // given
        let scenario = Scenario()

        // when
        let reaction = scenario.sut.reaction(to: .changed([
            RepositoryLocation(path: "/project/.git/worktrees/agent/index")
        ]))

        // then
        #expect(reaction == .refresh([WorktreeID(canonicalPath: "/project/.claude/worktrees/agent")]))
    }

    @Test(arguments: ["refs/heads/main", "packed-refs", "config", "info/exclude"])
    func `given shared Git metadata when it changes then every worktree using it is checked`(_ path: String) {
        // given
        let scenario = Scenario()

        // when
        let reaction = scenario.sut.reaction(to: .changed([
            RepositoryLocation(path: "/project/.git/" + path)
        ]))

        // then
        #expect(reaction == .refresh([
            WorktreeID(canonicalPath: "/project"),
            WorktreeID(canonicalPath: "/project/.claude/worktrees/agent")
        ]))
    }

    @Test(arguments: [
        "node_modules/library/index.js", ".build/build.db", "DerivedData/build.log",
        "Pods/Generated.swift", "target/classes/Reader.class", "dist/index.js", ".git/objects/ab/cdef"
    ])
    func `given generated output or Git object storage when it changes then no worktree refreshes`(_ path: String) {
        // given
        let scenario = Scenario()

        // when
        let reaction = scenario.sut.reaction(to: .changed([RepositoryLocation(path: "/project/" + path)]))

        // then
        #expect(reaction == .ignore)
    }

    @Test(arguments: [
        "/project/.git/worktrees/new-checkout", "/project/.git/worktrees/agent",
        "/project/.git/worktrees", "/project", "/project/.claude/worktrees/agent"
    ])
    func `given worktree registration or a watched root when it changes then inventory is reconciled`(_ path: String) {
        // given
        let scenario = Scenario()

        // when
        let reaction = scenario.sut.reaction(to: .changed([RepositoryLocation(path: path)]))

        // then
        #expect(reaction == .reconcile)
    }

    @Test
    func `given files in multiple worktrees when one event batch arrives then every affected worktree refreshes`() {
        // given
        let scenario = Scenario()

        // when
        let reaction = scenario.sut.reaction(to: .changed([
            RepositoryLocation(path: "/project/Sources/Root.swift"),
            RepositoryLocation(path: "/project/.claude/worktrees/agent/Sources/Reader.swift")
        ]))

        // then
        #expect(reaction == .refresh([
            WorktreeID(canonicalPath: "/project"),
            WorktreeID(canonicalPath: "/project/.claude/worktrees/agent")
        ]))
    }

    @Test(arguments: [
        "/project/.claude/worktrees/agent/.git",
        "/project/.git/worktrees/agent/commondir",
        "/project/.git/worktrees/agent/gitdir"
    ])
    func `given Git directory pointers when they change then observation topology is rediscovered`(_ path: String) {
        // given
        let scenario = Scenario()

        // when
        let reaction = scenario.sut.reaction(to: .changed([RepositoryLocation(path: path)]))

        // then
        #expect(reaction == .reconcile)
    }

    private struct Scenario {
        let sut = WorktreeObservationTopology(targets: [
            WorktreeObservationTarget(
                location: RepositoryLocation(path: "/project"),
                gitDirectory: RepositoryLocation(path: "/project/.git"),
                commonGitDirectory: RepositoryLocation(path: "/project/.git")
            ),
            WorktreeObservationTarget(
                location: RepositoryLocation(path: "/project/.claude/worktrees/agent"),
                gitDirectory: RepositoryLocation(path: "/project/.git/worktrees/agent"),
                commonGitDirectory: RepositoryLocation(path: "/project/.git")
            )
        ])
    }
}

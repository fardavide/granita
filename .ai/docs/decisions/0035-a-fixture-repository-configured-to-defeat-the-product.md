# A fixture repository configured to defeat the product

Every other fixture is built with `GIT_CONFIG_GLOBAL=/dev/null`, which means none of them can tell a
hardened invocation from an unhardened one. The whole of §5.1 could have been deleted and the suite
would have stayed green.

`.fixtures/hostile` puts that configuration in the repository's own config, where a child process
reads it whatever the environment says: no path prefixes, mnemonic prefixes, forced colour,
octal-escaped paths, hidden untracked files, and an external diff tool that fails. The generator
asserts each trap **with the others neutralised**, so one flag going missing from the product cannot
be hidden by another still working — a fixture that quietly stops being hostile makes the git
layer's tests pass for the wrong reason, which is worse than not having it.

Confirmed to bite by removing each pinned flag in turn and watching the suite go red, including the
two real-binary tests: without the prefixes git emits `"a/caff\303\250.txt" "caff\303\250.txt"`, and
without the untracked mode the status carries no untracked file at all.


# `CoreBrandingDomain`, a module the spec's tree does not list

SPEC §1 asks for the product name, bundle identifier prefix, Bonjour service type, URL scheme and
Application Support directory to live in "a single `Branding.swift`" so a rename is a two-file
change. Both units need those values, so a Core module is the only place that satisfies "single"
without a copy on each side. The alternative — putting them in `CoreDiffDomain` — would have made
the diff domain the home of unrelated constants.


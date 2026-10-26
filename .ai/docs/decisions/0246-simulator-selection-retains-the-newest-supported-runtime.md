# Simulator selection retains the newest supported runtime

Select the first supported numbered iPhone in the newest installed iOS runtime that contains
one. A later runtime without a matching model must retain the earlier valid selection. The
existing model filter and `OS=latest` destination remain unchanged.

CI run [39958096134](https://github.com/fardavide/granita/actions/runs/39958096134) failed both
iOS shards before tests started with `No recent iPhone simulator on this runner image`. The
runner image's published inventory contains numbered iPhones under iOS 27.0 followed by only
iPhone Duo under iOS 27.1. The selector cleared its valid result on every iOS header and
therefore returned an empty name for that inventory. A synthetic inventory reproduces this
failure with the production awk expressions.

The Makefile, workflow and both coverage collectors share this selection policy. Parameterized
tooling tests execute all four production expressions against inventories with successive
matching runtimes, a later unmatched runtime and no supported phone. Required suites, snapshot
baselines, motion assertions, coverage scopes and numeric ratchets are unchanged.

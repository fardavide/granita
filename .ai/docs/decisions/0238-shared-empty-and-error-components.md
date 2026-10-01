# Shared empty and error components

30 September 2026. [#114](https://github.com/fardavide/granita/issues/114) authorizes one shared
view module so changes to empty-state typography and error reporting have one home.

`Core/Components/Ui` compiles on iOS and macOS, imports SwiftUI alone and is main-actor by default.
Feature `Ui` targets may depend on this module, but no other `Ui` target. This narrows the layer
restriction recorded in 0010 without changing Presentation's dependency direction.

The empty component retains the native unavailable-content view and pins title2 bold over body.
The error component supplies prominent recovery styling and a borderless report action with ready,
copying, copied and failed states. Builders preserve conditional recovery, the searching symbol's
motion and the sidebar's diagnostic and elapsed-time placement. The report action also serves the
existing long-wait screen. Domain states are mapped exhaustively at each consuming boundary rather
than making the component depend on a feature or a Domain target depend on SwiftUI.

No design call changes and no baseline is re-recorded. Existing model tests cover the callbacks;
the existing snapshot subjects cover their drawn states.

Rejected: keeping four typography extensions and four report-action implementations. That made
one visual change require editing four modules. Rejected: allowing arbitrary dependencies between
feature view modules, which would let feature-specific screens become another feature's vocabulary.

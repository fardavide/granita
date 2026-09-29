# The QR is `Ui`, and CoreImage is not a fourth dependency

`CIQRCodeGenerator` is a system filter, and turning a value into pixels for rendering is `Ui` work in
the same sense SPEC §8 already pins Highlightr to `ClientViewerUi`: highlighting produces attributed
strings for rendering. Nothing in `PairingQrCode` decides anything — the link is the contract and the
picture is a function of it.

**It sizes itself from the module count rather than filling a fixed square**, which is why design §5
gives the size as a range. A 53-module code squeezed into 240pt puts some modules at four points and
others at five, and that unevenness is what a scanner reads as noise. Four points per module, eight
pixels per module, so the bitmap is an exact 2× of the drawn size and an exact 2:1 downsample at 1×.

**White behind it in both appearances**, which is functional rather than a hardcoded colour: a QR
inverted for dark mode is one most scanners will not read, and this is the one surface where a reader
is holding a camera up to the screen.


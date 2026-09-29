# The Xcode Cloud build number is a team-wide counter, and that is fine

Observed rather than documented by Apple: `CI_BUILD_NUMBER` increments across the whole developer
account, not per app. Granita's first builds were 70 and 71 because another project of Davide's had
reached 69.

Left alone deliberately. App Store Connect requires `CFBundleVersion` to be unique and **increasing
within one app's release train** — every build sharing a `CFBundleShortVersionString` — and does not
require it to start at 1 or to be contiguous. Gaps appear whenever the other project builds, and
that is valid. The only thing lost is being able to read "how many Granita builds" off the number;
buying that back would mean replacing Apple's counter with our own, which is more machinery and a
new way to collide, for cosmetics.


# Seasonal icons preserve the saved choice

The iPhone and iPad picker follows Aura's seasonal icon settings. Save the usual icon alongside the
existing schedule. A manual selection leaves the schedule in place. Christmas takes precedence from
December 1 through January 7 in the device's local Gregorian calendar. Turning the switch off or
leaving that window restores the saved icon. UIKit reports the displayed icon, and the picker marks
the saved selection separately.

On upgrade, retain the old schedule. Use the icon UIKit reports as the first saved choice. If the
old automatic schedule is showing Christmas, seed the usual choice with Granita, which was the
previous schedule's off-season icon. A manually chosen Christmas icon remains a valid saved choice.
Save this migration before requesting a system change. A refused request leaves both settings in
place and reports the icon UIKit kept.

This updates the choice behavior in [decision 0267](0267-follow-the-christmas-calendar-for-the-mobile-icon.md)
and the storage decision in [decision 0233](0233-two-icons-and-only-the-phone-chooses.md).
See the [Aura implementation](https://github.com/fardavide/Aura/pull/82) and the
[picker design](../design-appearance.md#the-app-icon).

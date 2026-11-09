# Slim Suite

An addon for Azeroth Survivors by Slimjim: a movable default UI with a set of small extras.

## Install

1. Download the latest `SlimSuite-<version>.zip` from the Releases page.
2. Windows or Linux: extract the `SlimSuite` folder into `benilla-config/AddOns`, next to the game's executable.
   In the browser: Options → AddOns → Install AddOns, and pick the zip.
3. If an older `AZSMinorMods` folder is there (Slim Suite's old name), delete it.
4. The addon loads at your next world entry.

Open the settings with `/slimsuite` (or `/slim`), or the gear button by the minimap.

## The game's own HUD

When Slim Suite replaces part of the game's HUD (the meter, run clock, boss bars, tally, build rows, banners, Level Up!
button, revive bar or local clock), it hides the game's version with the game's own "Show …" setting, and turns it
back on when you turn the replacement off. Those settings are saved by the game, so if you remove Slim Suite while a
replacement is on, turn the part back on in Options → Interface.

## Source

The addon files are in the `SlimSuite` folder. Edit them, then zip that folder to test your own build.

- `SlimSuite.lua`: settings, chat filters, the movable UI and its replacements.
- `SlimSuiteWorld.lua`: features built on the game's newer addon API (world markers, downed friends, minimap pins,
  lairs, revive bar, proc meter, local clock, combat text). Its adapter section at the top is the only
  place that reads those API calls, following the game's addon docs.
- `SlimSuiteMeter.lua`: the movable damage meter (Damage, Healing, Boss and Party tabs).
- `SlimSuiteItems.lua`: the jewelry icon catalog.
- `AZSKit.lua`: the shared look of the AZS addons (window, buttons, minimap button), a copy of the launcher's file.
- `SlimSuiteCore.lua`: the shared namespace (`SS`), error-logging calls and the one timer the other files use.
- `SlimSuiteErrors.lua`: the error log (`/slimsuite errors`), kept between sessions.
- `textures/`: Slim Suite's own textures (the square minimap's mask).

## Releases

Each release attaches `SlimSuite-<version>.zip`, which contains the `SlimSuite` folder.

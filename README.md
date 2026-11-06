# Slim Suite

An addon for Azeroth Survivors by Slimjim: a movable default UI with a set of small extras.

## Install

1. Download the latest `SlimSuite-<version>.zip` from the Releases page.
2. Extract the `SlimSuite` folder into your game's `Interface/AddOns` folder.
3. If an older `AZSMinorMods` folder is there (Slim Suite's old name), delete it.
4. Restart the game.

Open the settings with `/slimsuite` (or `/slim`), or the gear button by the minimap.

## Source

The addon files are in the `SlimSuite` folder. Edit them, then zip that folder to test your own build.

- `SlimSuite.lua`: settings, chat filters, the movable UI and its replacements.
- `SlimSuiteWorld.lua`: features built on the game's newer addon API (world markers, downed friends, minimap pins,
  lairs, revive bar, proc meter, local clock, combat text). Its adapter section at the top is the only
  place that reads those API calls.
- `SlimSuiteMeter.lua`: the movable damage meter (Damage, Healing, Boss and Party tabs).
- `SlimSuiteItems.lua`: the jewelry icon catalog.
- `AZSKit.lua`: the shared look of the AZS addons (window, buttons, minimap button), a copy of the launcher's file.

## Releases

Each release attaches `SlimSuite-<version>.zip`, which contains the `SlimSuite` folder.

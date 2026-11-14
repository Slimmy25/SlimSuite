# Slim Suite

**Default+ for Azeroth Survivors.** The familiar game interface, with more control over where everything goes, how it looks, and what you see.

Made by **Slimjim**, Slim Suite combines a customizable HUD with combat tools, co-op helpers, minimap improvements, chat filters, and optional sound alerts. Keep the classic Warcraft look, choose a cleaner style, or mix the two as you build your own layout.

[Download the latest release](https://github.com/Slimmy25/SlimSuite/releases/latest) · [See what's new](CHANGELOG.md)

## Default+, one element at a time

Slim Suite's UI settings let you build your interface piece by piece. Start with your player frame, add the party frames, move your action bar, then decide what else belongs on your screen.

On a **fresh installation**, setup opens with the managed HUD elements disabled, including their original game versions. You choose which elements to bring back and which versions to use. Existing saved setups are preserved.

Every element has three clear choices:

| Choice | What it does |
| --- | --- |
| **Enabled** | Shows Slim Suite's movable/custom version. Its green box lets you position it during setup. |
| **Disabled** | Hides both Slim Suite's version and the original game element. |
| **Default** | Restores the original Blizzard/Aethus element and its game HUD visibility setting. |

**To build your layout:**

1. Open `/slim setup` and select **Enabled** beside an element.
2. Drag its green box to put it where you want it.
3. **Right-click the element's name** for its appearance, size, scale, and other available options.
4. Add the next element when you're ready. Use **Demo** to preview the elements you've enabled with sample activity.
5. Press **Done** and confirm when your layout is ready. Reopen setup whenever you want to change it.

### Make the HUD yours

- **Player, target, and party frames:** keep classic portraits or use cleaner custom frames. Mirror the target frame, arrange the party in a row or column, or include yourself in the party list.
- **Buffs and debuffs:** attach your buffs around the player frame, choose the target's aura position, and show teammates' buffs above their frames.
- **Action and build bars:** keep or hide the action bar artwork, turn supported bars vertically, add cooldown numbers, and optionally show your racial ability. Keep build spells and equipped jewelry joined together or separate them.
- **The rest of your HUD:** position the XP bar, chat, tooltips, damage meter, encounter bars, run clock, announcements, stored level-up button, revive bar, and local clock.
- **Kills, gold, and cache cost:** use a vertical or horizontal tally, with optional map name, named difficulty, and boss/Guardian kill counts.
- **Placement tools:** use the alignment grid, center guides, and optional snapping. Resolution-aware sizing and recommended HUD positions give you a starting point for different screen shapes.

### Save a layout you like

Save named profiles, keep separate layouts for different characters, and import or export layouts to share them. You can also export your saved profiles together. Editable copies made from creator presets save your changes without altering the original preset.

## More than a UI editor

### Combat information you can place where you need it

- **Movable damage meter** with Damage Done, Healing Done, Boss Damage, and Party DPS views.
- **Encounter bars** with horizontal or vertical layouts, adjustable thickness, name alignment, raid markers, and debuff timers. DoTs sit at the far end of each bar, away from its raid marker.
- **Enemy nameplates:** use the game's plates or Slim Suite's modern frames. Optional boss/Guardian debuff icons and remaining times work with either style when the game supplies that data.
- **Combat text:** use a movable combat-text box or floating text over enemies, with options for spell icons, heals, critical hits, duration, and motion.
- **Class proc meter** and optional green absorb overlays with numeric shield amounts. Teammate shield values appear only when the client provides them.
- **Stored level-ups and revive progress** in movable controls, plus an option to keep Slim Suite overlays above level-up and item-selection cards.

### Help for co-op and finding your way

- Mark bosses and Guardians already in combat, with optional markers for Guardians and lairs before combat.
- Mark where a downed teammate can be revived.
- Show a raid-marker selection row when hovering over a party member while grouped.
- Add cache, boss, and lair pins to the minimap, including lair refill timers and the nearest-Guardian-lair flag.
- Use the extended camera-distance option for a wider view.

### A minimap that fits your layout

Choose a **round or square minimap**, with an optional transparent, borderless appearance. Keep buttons around the map or gather them above, below, left, or right. A separate movable button row is also available.

The local clock supports 12-hour or 24-hour time, a background toggle, and placement attached to or separate from the minimap.

### Less noise in chat

Choose which repetitive messages to hide: level-up stat bonuses, newly learned spells, racial-buff information, and roleplay lines. Add your own word filters with `/slim hide <words>` and remove them with `/slim unhide <words>`.

### Optional sounds, with previews

Listen to each included sound before enabling it:

- **Death or a downed teammate:** Baby Crying or LEGO die.
- **Low health:** a short warning at 30% health or below, with at least five seconds between alerts.
- **Boss, Guardian, or lair-owner kills:** Hitmarker and/or Whip Crack.
- **Opening a cache:** Zelda chest-opening audio, triggered by the game's confirmed opened-cache counter.

### Readability and support

Use higher-contrast encounter bars, larger encounter names, and reduced combat-text motion. The interface supports **English, Spanish, French, German, Portuguese (Brazil), and Italian**. Follow the client language automatically or choose one in settings, then reload the UI. Game-provided names stay in the game's language.

Built-in diagnostics show detected client features and compatibility information. The persistent error log keeps Slim Suite errors available between sessions, and the addon manager lets you enable or disable other installed addons before reloading.

## Install

1. Download `SlimSuite-<version>.zip` from the [latest release](https://github.com/Slimmy25/SlimSuite/releases/latest).
2. **Desktop:** extract the `SlimSuite` folder into your game's `benilla-config/AddOns` directory. **Browser:** use **Options → AddOns → Install AddOns** and select the ZIP.
3. If you still have the old `AZSMinorMods` addon installed, remove that old addon folder so you aren't running both versions.
4. Enter the world, or reload the UI if you're already in-game. Open settings with `/slim`, `/slimsuite`, or the gear button by the minimap.

## Handy commands

| Command | Use |
| --- | --- |
| `/slim` | Open settings. |
| `/slim setup` | Open the element setup menu. |
| `/slim edit` | Unlock the UI for editing. |
| `/slim lock` | Lock the UI. |
| `/slim demo` | Toggle the enabled elements' demo. |
| `/slim layout` | Open profiles and import/export. |
| `/slim hud` | Open recommended HUD positions. |
| `/slim errors` | Open the saved error log. |
| `/slim diagnostics` | View compatibility information. |
| `/slim minimap` | Show or hide Slim Suite's minimap button. |
| `/slim help` | List the available commands. |

## For contributors

Production addon files live in [`SlimSuite/`](SlimSuite/). Translation dictionaries live in [`locales/`](locales/); regenerate their Lua tables with `python tools/build-locales.py` after editing them.

See the [changelog](CHANGELOG.md), [client API notes](docs/api-compatibility.md), and [completed work and remaining checks](docs/code-review.md) for more detail. The automated checks are in [`SlimSuite/tests/`](SlimSuite/tests/), including behavior scenarios and compilation with Lua 5.0.3.

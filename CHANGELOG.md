# Slim Suite changelog

Newest first. Each release's notes on GitHub are taken from its section here.

## 1.31
- Reviewed enemy-nameplate lifetime and projection handling: failed catalog reads cannot corrupt live records, pooled plates reuse their children, projections match anchor IDs and scale, and stale/missing projections hide immediately. Catalog failures back off instead of retrying every frame.
- Default restores native frame scaling, buff icon anchors, party-member anchors and XP-bar parenting/orientation; opening setup no longer immediately detaches a Default XP bar again. Explicit Disabled/Default choices prevent legacy native-HUD auto-adoption.
- Profiles retain additional HUD settings, minimap button placement and native-layout ownership. Exports have stable ordering; imports reject invalid types, non-finite/excessive geometry, incomplete sizes and cyclic anchors before applying.
- Cached unchanged display-template calculations and foreground registrations; reused profile snapshots during automatic saves. Absorb overlays stay inside health bars and allocate no controls while disabled.
- Low-health warnings repeat while health remains low, stop at death/recovery and retain the five-second minimum interval. Localized boss/Guardian tally labels and filled three missing French/German labels. Diagnostics no longer invent a stale installed version when metadata is unavailable.
- Added code-audit regressions, localized smoke checks and fail-fast module/startup checks; corrected the mock client's frame-name identity.
- Pending custom-profile edits flush at logout. Unavailable cache data no longer triggers a chest-opening sound.
- Demo controls now read Demo / On / Off followed by the right-click settings hint. Both minimap shapes retain the native map title and close button; enabling the minimap restores visible map opacity instead of caching setup's hidden state.
- Enabled immediately selects movable/custom mode and clears the old immovable flag. Attached party portraits align with the player's portrait center instead of frame padding. Selecting player buffs enables Buffs and makes above-frame rows grow upward.
- Unit-card refreshes keep native and New-school versions mutually exclusive during setup, including when changing only Target's style. Disabled custom player/target cards cannot reappear on a timer refresh.
- Removed the unsuccessful Move to begin foreground-layer workaround from 1.30. Enabled starting HUD values remain visible before movement.

## 1.30
- During Move to begin, register Slim Suite HUD, setup windows, move handles, and enabled managed native elements with the game's foreground overlay API; restore temporary registrations when leaving ready. Rendering above the native prompt still requires an in-game check.
- Enabled Kills / Gold / Cache is visible at Move to begin with starting values, and the ready timer stays at 00:00. Event-driven elements remain hidden when empty outside setup or Demo Mode.

## 1.29
- Kept the setup completion confirmation visible above the element menu. Mirror Target now calculates equal outer screen margins using the actual screen bounds.

## 1.28
- Disabled native HUD elements now remain hidden when their replacement updates. Fresh-install setup starts with both versions disabled, ready for a preset or manual setup. Done asks for confirmation and explains how to reopen setup with /slim setup.
- Reworked chat layout handling around the native dock: the real shared edit box keeps both width anchors, docked windows and controls scale together, setup preserves the selected tab, and Default restores native geometry and scaling. Disabled and muted states now cover the docked group and restore the input box correctly.
- General and Combat Log tabs share a baseline above the chat window and remain aligned after native dock updates; separately undocked chat tabs keep their own position.
- Announcements Disabled now hides both the game and Slim Suite versions; Enabled immediately hides the original, and Default restores it. Incoming banners and setup exit preserve the selected visibility.
- Native enemy-nameplate controls use the original 1.12 show/hide functions instead of the unsupported nameplateShowEnemies CVar. Regression checks cover nameplate restoration and buff layout without GetEffectiveScale.

## 1.27
- Added optional LEGO die death sound, hitmarker and whip-crack boss/Guardian/lair-owner kill sounds, and a Zelda-style cache-opening sound. Added an in-game preview button for each included sound so players can audition them before enabling.
- Setup rebuilds preserve party, minimap and clock choices; only selecting Default restores the game's settings. Updated the automated harness to load all addon modules and retain CVar changes.
- New installs open directly into setup with all native and Slim Suite elements Disabled; enabling an element immediately opens its controls and exposes its move handle.
- Added an attached Default profiles side panel with reserved slots for the profiles to be provided later.
- Choosing Default now explicitly restores the Blizzard/Aethus element and turns its game HUD visibility setting on; the movable replacement is turned off. The Level Up default restores the native Level Up button through the game's HUD API without displaying a chat command.
- Added a disabled-by-default low-health sound option using the supplied sound asset; it triggers at or below 30% health, is rate-limited to once every five seconds, and requests a one-second playback window.
- Added the Stat counter [WIP] setup placeholder and a read-only creator preset pathway that creates a numbered My Custom Profile copy before applying changes.
- Added native enemy-nameplate control and optional modern Slim Suite overlays, with a boss/lair-guardian filter, raid marks and documented boss/guardian debuff timers; ordinary enemy overlays are limited to 64 at a time.
- Added optional green absorb markers and numeric amounts to player and party health bars when the client exposes the data.

## 1.26
- Added a parenthetical hint beside Demo explaining that right-clicking an element name opens its settings.

## 1.25
- Toggle UI Settings enables movable Slim Suite elements by default on first use; users can set each element to Enabled, Disabled, or Default. The element name itself is non-clickable, with right-click opening its settings.
- Kills / Gold / Cache can show or hide the map name and named difficulty (Normal or Heroic 1–5) instead of a numeric multiplier.
- Removed the movable minimap button row's vertical/horizontal style control while retaining ring and top, bottom, left and right placement choices.

## 1.24
- Expanded HUD profiles with named save/apply/delete, single-layout import/export, and portable bundles for all named profiles; per-character layout support remains available.
- Added a display-aware recommended HUD preset action that repositions enabled elements using the selected aspect-ratio template while leaving Default and Disabled elements alone.
- Added encounter bar thickness and name-alignment controls, plus accessibility settings for high contrast, larger encounter names, and reduced floating-text motion.
- Added a diagnostics and compatibility view with addon/game versions, detected display template, saved profile count, and relevant Azeroth Survivors API availability.
- Slim Suite's patch version now appears in Settings, diagnostics, and the minimap-button tooltip.

## 1.23
- Automatic display layouts select among standard, ultrawide and portrait templates, keeping the reference HUD positions proportional to the viewport.
- Element sizes follow screen height with narrower-screen density adjustments; custom size multipliers remain relative to the automatic size.
- Custom locations saved with display bounds adapt proportionally across resolutions and restore when returning to the original display.
- Default-state elements remain controlled by the game.
- Slim Suite now follows the game client language for its setup, settings, edit controls, error log and common HUD labels in Spanish, French and German, with English fallback for other locales and untranslated text.

## 1.22
- **Screen edges:** dragging, saved positions, live boundary checks and the edit grid now share measured screen bounds, including the world viewport when the UI root occupies a smaller area. Scaled elements retain their visible bounds when placed against an edge.

## 1.19
More predictable UI setup, with native defaults preserved until you opt in.

- **Toggle UI Settings:** every element now has Default, Enabled and Disabled states. Default restores the game's UI; Enabled uses Slim Suite's movable version; Disabled hides the element.
- **Demo Mode:** only elements enabled before Demo starts are previewed. Turning one off during a preview removes it from the demo.
- **Element list:** compacted the list and placed Reset All beside Done at the lower-right corner.
- **Mirrored frames:** Player and Target now use one Mirror Target setting and stay the same size and scale.
- **Buffs and debuffs:** attached auras wrap within the player's or target's frame bounds and grow outward from the selected edge.

## 1.17
Clearer demo and minimap details.

- **Demo Mode XP bar:** purple progress steadily fills and returns to empty at 100%.
- **Combat text:** hits drift right more slowly and use smaller text.
- **Square minimap:** the map title stays visible above the map, its border fits below the title, and the map button joins the square edge layout.
- **Transparent minimap:** optional for round or square maps, with borders removed.
- **Kills / Gold / Cache:** shows the current map and the documented difficulty multiplier when available.

## 1.16
Demo Mode runs the whole interface like a real run, big hits pop, and raid marks show on the encounter bars.

- **Demo Mode:**
  - Four sample bosses and the target only ever lose health, then start again full.
  - The party takes ticking damage, heals and big hits in short bursts, and the revive bar fills and starts over.
  - Kills, gold and the cache price only climb, then start again from 0.
  - The run clock counts up from a random time while the next boss counts down.
  - Announcements of different lengths show every few seconds.
  - The minimap shows sample caches and walking bosses with their marks.
  - Starting it from the element list closes the list and shows only the small DEMO MODE box.
- **Raid marks on the encounter bars:** each boss or Guardian bar shows the same mark that is over its head and on the minimap.
- **Combat text:** crits and your biggest hits grow, drift to the right and slowly fall away. How much depends on how big they are next to your normal hits. This can be turned off in the combat text box's menu.
- **Your buffs in the party:** a row ends where your plate's health and mana bars end.

## 1.15
Buffs where you want them, a proper square map, and a tidier settings window.

- **Party buffs:** your buffs and every party member's buffs sit above their plate, lined up with the portrait. Rows stop before the next party member and grow down when there are many. Friends' buffs can be turned off in the party's menu.
- **Your buffs vs the target's:** your buffs go in their own place or above, below, left or right of the player frame. The target's buffs and debuffs have their own side setting in the target's menu. Turning on Mirror target offers to match them.
- **Square map:** its ring now has the round map's colours and can never show on the round map. Slim Suite's gear sits on the ring, round or square, at the same distance as the game's own buttons.
- **Minimap button row:** optional (off by default). Its buttons are visible again instead of an empty grey box.
- **Encounter bars:** their green box fits on the screen again.
- **Game settings:** a part you turned off in the game's Interface settings (Run Clock, Boss Bars ...) gets Slim Suite's movable version once, automatically.
- **Settings window:** the UI page now only asks the "Replace Default ... with Movable Version?" questions; each element's other settings are in its own menu.
- **Element list:** two columns, can be dragged anywhere, and has Demo On / Off beside the grid.

## 1.14
One list for moving and switching everything.

- **Toggle UI Settings** now always opens the element list: every element Slim Suite can change, each tagged Enabled, Disabled or Connected. The old move panel (Choose element, ALL?, Run setup again, centre lines) is gone.
- **Grid** sits on top of the list: a tick box and 16 / 32 / 64 / 128 blocks. **Done** at the bottom closes the list.
- **Every element is listed, on or off.** Turning one on in the list turns its feature on and gives it a green handle, including the combat text box.
- An element's own menu has just a Done button, which closes that menu.

## 1.13
Under the hood: Slim Suite is split into smaller files, and the unit frames react to the game's events.

- **Faster unit frames:** the player and target cards, the party's lines, your party plate and the raid marks now update the moment health, power, level, target, party or marks change, instead of waiting for the next check. The checks still run, less often, as a safety net.
- **Smaller files:** the main file is split into five (basics, frames, edit mode, setup, commands). Nothing changes in the game, and the settings are kept. If you install by hand, replace the whole SlimSuite folder.

## 1.12
The damage meter looks like the game's own, the square map gets a gold ring, and Demo Mode is easier to use.

- **Damage meter:** each pet or summon now has one line under its own name (Voidwalker, Imp ...), with all its attacks added together, as in the game's meter. Hover a pet's line to see its attacks. Lines are numbered, show amount (dps, share %), have bigger icons and coloured bars, and a "proc" tag on procs.
- **Connected:** in the setup list, an element that is joined to another (your player frame in the party, buffs on the player frame, a combined target) now says "Connected" instead of looking off. Hover the tag to see what it is joined to.
- **Square map:** a gold ring around it like the round map's border. The zoom buttons, the moon and other addons' buttons sit on the ring at the same places as on the round map, and the zone name sits on top of it.
- **Clock:** once the map is square or moved, Slim Suite's clock replaces the game's so it stays with the map.
- **Your buffs in the party:** they start at your plate's top-left corner and grow to the right. When a row is as wide as your plate, a new row starts above, so they never reach the next party member.
- **Demo Mode:** keeps your party's column or row. Slim Suite's menus close and a small "DEMO MODE" box with On and Off shows instead; Off brings the menus back.

## 1.11
Fixes and speed. Nothing new to learn.

- **Boss and Guardian kills:** one counts as killed once it drops to 3% health or less (or dies). One that just leaves sight alive no longer counts.
- **Setup:** if something goes wrong during the setup, it closes cleanly and gives your interface back instead of leaving it half done. Resetting during the setup no longer leaves a gap.
- **Mirror target:** in Edit mode it no longer changes your setup choices.
- **Jewelry names:** rings and amulets show their real name, taken from the item itself. The item list is updated (39 items).
- **Error log:** only Slim Suite's own errors are kept. Errors from while the game was loading are kept too.
- **Speed:** world markers, floating text, boss bars, the meter and Edit mode do less work each second.
- **Timers:** starting or stopping a timer from inside another no longer skips or repeats one.

## 1.10
Review fixes, a faster idle, saved layouts and new commands (`/slim help`).

## 1.09
The right-click menu on any element is now the setup menu.

## 1.08
Your buffs line up with your party plate.

## 1.07
You first in the party, raid marks on frames, tooltip placement, and the XP bar keeps the game's border.

## 1.06
Frame looks per frame, party layout and thin lines; previews only while editing.

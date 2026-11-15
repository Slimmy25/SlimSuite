# Slim Suite changelog

Newest first. Each release's notes on GitHub are taken from its section here.

## 1.38
- Demoted weak crits now use normal white text, normal font size and no critical suffix or rightward effect. Highlight selection checks both the source baseline and the player’s learned overall damage.
- Reserved normal-log capacity so critical highlight bursts cannot consume every row and erase ordinary damage.
- Added a separate optional Load-in song (Move to Start) selector. It plays once on entering the ready screen, independently of the existing Ready → Playing start-song option, with protection against repeated polling and temporary missing phase data.

## 1.37
- Added normalized GTA V Wasted exclusively to final match-loss choices, separate from recoverable player/teammate death audio. Future audio additions require normalization and measured-asset checks before release.
- Added an independent teammate death selector with Roblox and Same as player, plus an optional GTA San Andreas victory sound that plays once per win.
- Leveled all 13 MP3 assets to a common -12 LUFS target (original Whip Crack + 1.5 dB), with limiting and endpoint fades. Decoded true peaks remain below -1 dBTP; included reproducible build-time normalization and asset checks.
- Added Duck Toy to player/teammate death sound choices, The Price Is Right losing horn to a separate match-loss group, and Kit Kit Kit as an optional match-start song.
- Ordinary death sounds wait briefly for the run result; confirmed defeat clears them and plays only the selected game-over alert. Start songs play once on Ready → Playing; victories, leaving and historical end screens do not replay loss audio.
- Combat highlights now learn per-source damage and critical-hit frequency, blending baselines each minute. Routine repeated crits remain in the downward log; rare or unusually strong hits use the rightward highlight rows. Learning resets per run and is bounded to 64 recent sources.
- Combat text animates every rendered UI frame, with cached, UTF-8-safe binary-search text fitting.
- Sound events now offer one selected sound or Off. Small speaker icons beside each option replace standalone preview buttons; added the supplied Gotcha sample for boss/guardian/lair kills.
- Trimmed the Zelda chest sound to its final four-note phrase (about 2.5 seconds).
- Added raw death-notification, confirmed corpse-anchor and authoritative boss/guardian counter fallbacks for kill sounds, with cross-source deduplication and silent historical initialization.

## 1.36
- Normal combat hits now stack downward without horizontal drift. Crits have their own top-to-bottom row cursor, fading right within bounds; normal rows avoid active crits and wrapping clears the prior crit before reuse.
- Fixed both optional boss/guardian/lair-owner kill sounds to use confirmed game death banners, independently of visible announcements. Deduplicated callback and polling delivery; loading historical banners does not replay old kills.

## 1.35
- Fixed build refreshes reopening green handles during Demo; editor previews and demo previews now have separate predicates.
- Encounter clicks now wait for authoritative target updates instead of cycling against stale server data; failed restoration is checked by spawn ID.
- Normal Explosive Orbs are discovered through living world anchors. Their encounter rows show real target/unit health when available and explicitly report unavailable health otherwise.
- Removed the unused combat popup pool/animation. Large-hit emphasis now uses the same bounded rainfall rows; renamed its setting and translated the new labels in all six supported locales.
- Explosive Orb takes first encounter-bar priority and reserves Skull ahead of bosses.
- Combat text uses separate downward tiers with rightward drift; tier reuse retires the prior hit.
- Demo mode hides all editor handles and restores them afterward. Grid choices are now 8/16/32/64; the compass is included in fresh setup defaults and remains editable on older profiles.
- Damage meters now request actor-level credits and combine each owner's pet/summon attacks without folding them into player spell rows.
- Player buffs above the frame use larger icons while retaining two-row bounds and collision checks.
- Removed duplicate guardian/lair waypoints. Encounter bars exclude ordinary elites, and clicks verify the exact hostile encounter ID instead of targeting by name.
- Compass and minimap share a per-frame moving-encounter position query. Active guardians join boss tracking; unavailable coordinates clear instead of retaining a stale marker.
- Selection screens temporarily show a horizontal item row beneath the native spell strip, sized from the supplied reference. Normal hidden/muted state, split/joined layout, sizing, orientation and scale remain unchanged and restore on exit.
- Exempted native minimap chrome from generic child clipping and released suppressed textures; restored the moon, top-right controls and full zoom buttons above the square ring.
- Attached local time now stays directly beneath the minimap border through layout rebuilds, using scale-correct spacing. Detached clocks retain their own positions.

## 1.34
- Combat log mode now suppresses native CombatDamage numbers and restores the original setting on exit/logout. Added native-number retention, all-enemy icons/critical hits, and boss-only damage modes, with an optional accompanying log.
- Build hover uses exact spell hyperlinks or matching real spellbook descriptions before an explicit unavailable message. Pregame cooldown labels read the actual starting spell/racial payload and show reported remaining time or the full interval without a fake countdown.
- Removed minimap rim clamping: points stay at reported world positions and disappear outside range. Bosses use their raid icons and names. Known pregame positions are dimmed; absent future coordinates are never fabricated.
- Added an optional rail/free-marker compass with Boss, Lair and Chest filters. Docked Build along the lower screen edge and Stats at the upper-right during card choices, with on-top tooltips and exact anchor restoration.
- Lowered only the square minimap body beneath its native title; the round-map anchors restore unchanged. Refined the stored-level button with a restrained interior glow, bronze gradient and contained count, without hover enlargement.
- Added shared region containment for movable elements and text truncation after minimum-font fitting. Tiny saved sizes respect element minimums; fitted tally dimensions are retained across later placement passes.
- Reserved explicit icon and glyph space for combat rows and popups, sanitized multiline hit names, and suppressed overflow at the same bounds used by green handles.
- Made Stats start at the damage meter’s 230 × 170 size, with internal scrolling, per-stat visibility grouped in its right-click menu, and live combined or pre-run Default + Bonus display.
- Added optional placement of the run-clock location and Normal/Heroic label above the time; either position stays inside the clock frame.
- Added corner-drag resizing for movable HUD elements, with persisted scales and linked build-row sizing. Split spell and jewelry rows now have independent visibility and optional matched icon sizes.
- Replaced the stats placeholder with live documented character-pane totals, current/max HP and aggregate shield, racial information, and active buff timers. Item, spell and racial bonuses are not added twice.
- Removed the redundant tooltip-width footer and stored-level checkbox. Stored levels follow the game setting; the addon no longer changes it. Added an XP-border visibility option for either orientation.
- Removed the optional replacement switches from UI settings. Added Go back to vanilla directly below Toggle UI Settings to reset positions, restore all native HUD parts (including stored level-ups), disable custom HUD replacements and overlays, and lock the editor. Reopening the editor explicitly resumes the custom HUD.
- Removed minimap button gathering, directional sorting and the independent movable collection box for both map shapes. Saved collection settings are retired, and buttons stay around the minimap.
- Fresh installs enable all managed custom HUD elements at their default positions, replacing the corresponding game UI. Existing saved layouts retain their choices.
- Replaced the visible element-state list and preset sidecar with a compact grid, Demo On/Off, Reset All and Done panel. Right-click green move boxes for individual settings.
- Confined combat-text popups and their text to the movable combat box; falling hits expire at its edges rather than the screen bottom.
- Removed the extra gap beneath the cache location/difficulty heading and kept horizontal counters inside the element bounds.

## 1.33
- Attached player and party buffs now use at most two rows within their portrait-and-health-bar width, including room for duration text. Rows avoid other visible HUD frames and the screen edges; party buffs also leave the player's buff area clear. Icons that cannot fit safely stay hidden until space is available, and detaching restores their original scale and mouse behavior.

## 1.32
- Moved encounter/boss DoTs to the far end of each health bar: right-aligned underneath horizontal bars and below the bottom of vertical bars, away from raid markers.
- Consolidated element metadata and derived native ownership, setup order, movable lists, companions and display anchors from the shared registry. Enabled/Disabled/Default governs replacement rendering and legacy checkbox transitions; old saved choices migrate without resetting onboarding.
- Split setup into onboarding, settings controls, editor state, unit-frame rendering, setup windows and settings-window modules while preserving manifest load order and saved profiles.
- Replaced unconditional profile polling snapshots with dirty tracking on edits, debounced saves and a logout flush.
- Added a checksum-pinned upstream Lua 5.0.3 compilation check to CI and explicit mock API methods with geometry validation.
- Consolidated translations into validated JSON dictionaries and generated Lua tables. Added complete Portuguese and Italian dictionaries, a language selector, translated dropdown choices and settings rows that grow for wrapped text.
- Added optional documented boss/guardian DoT attachments for native enemy nameplates, with the same timing data as modern plates; fresh installs keep this option off.
- Cache sounds now use the documented AZS_RUN.ck opened counter instead of disappearing cache entries. Teammate shield amounts remain unavailable without a client-provided absorb query.
- Added architecture, native-plate, state-authority, idle-autosave, translation-completeness and text-layout regression checks.

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

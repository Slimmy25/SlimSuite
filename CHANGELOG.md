# Slim Suite changelog

Newest first. Each release's notes on GitHub are taken from its section here.

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

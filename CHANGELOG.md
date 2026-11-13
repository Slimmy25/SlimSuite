# Slim Suite changelog

Newest first. Each release's notes on GitHub are taken from its section here.

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

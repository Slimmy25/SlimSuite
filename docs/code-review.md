## Done

- Fixed enemy-nameplate corruption after interrupted catalog reads.
- Fixed nameplate control accumulation, incorrect projection matching, scaling, and stale plates remaining visible.
- Made Default restore native scaling, party anchors, buff layouts, and XP-bar parenting, orientation, and artwork behavior.
- Prevented automatic HUD replacement from overriding explicit Disabled or Default choices.
- Expanded profile settings coverage, validated imports, stabilized exports, and saved pending edits at logout.
- Reduced repeated display calculations, unit searches, projection allocations, foreground registrations, and profile copying.
- Kept absorb overlays inside health bars and avoided allocating them while disabled.
- Made low-health alerts repeat while needed, respect the five-second interval, and stop after death or recovery.
- Prevented unavailable cache data from triggering chest-opening sounds.
- Fixed untranslated boss/Guardian labels, three missing French/German labels, and misleading version diagnostics.
- Strengthened module-load/startup checks and corrected frame identity in the mock client.
- Passed 30 mock-client scenarios, 10,000 randomized UI actions, and compatibility checks. Changes are saved locally in the addon checkout; they have not been published.

## Still to do

- Consolidate repeated element definitions into one shared registry.
- Make Enabled/Disabled/Default the authoritative state and reduce overlapping visibility flags.
- Split the large setup module into focused editor, settings, onboarding, and unit-frame modules.
- Change profile autosave to run after actual edits instead of copying and comparing the layout every second.
- Tighten API mocks and add compilation checks using an actual Lua 5.0 runtime.
- Complete translation coverage beyond English, Spanish, French, and German; check translated text fit in-game.
- Implement DoT overlays on native enemy nameplates using documented client data.
- Replace chest-disappearance detection with a confirmed opening event or counter if the game exposes one.
- Confirm party shield-data availability; teammate absorb amounts cannot be shown when the client provides no authoritative values.
- Test in the actual game: screen-edge placement, scaling, XP artwork, minimap shapes/title/close button, party alignment, buff wrapping, and compatibility with other addons. Mock-client checks do not verify rendering.

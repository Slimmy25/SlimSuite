## Done

- Fixed the nameplate, native restoration, profile import, absorb overlay, sound and diagnostic defects from the initial review; published those fixes as version 1.31.
- Consolidated element metadata into a shared registry for native ownership, setup order, movable elements, feature flags, companions and display anchors.
- Made Enabled/Disabled/Default authoritative for replacement rendering and legacy settings transitions; retained compatibility reads for older saves.
- Split setup into focused onboarding, settings, editor, unit-frame and window modules.
- Changed profile autosave to take snapshots after edits, with a logout flush; idle polling no longer copies layouts.
- Tightened mock APIs and numeric geometry checks; added actual upstream Lua 5.0.3 compilation to CI.
- Consolidated translations into validated dictionaries. English, Spanish, French, German, Portuguese and Italian each cover all 517 dictionary keys. Added language selection and translated dropdown choices.
- Made settings rows grow for wrapped translations without shrinking the font.
- Added optional native-nameplate boss/guardian DoT attachments using documented timing/projection data.
- Replaced cache-disappearance sounds with the documented opened-cache counter, AZS_RUN.ck.
- Confirmed that the documented party data lacks shield totals; teammate values remain conditional on a real client absorb API.
- The canonical suite currently defines 54 behavioral scenarios, including locale variants. Historical randomized action counts are not a claim about the current run. Mock scenarios remain separate from actual Lua 5.0 compilation and native rendering.
- Included the refactor and encounter-bar DoT placement changes in version 1.32.

- Added a 17-row native UI acceptance matrix and a capability review for revives, shields, future positions and localization.
- Exercised stationary native setup/minimap/module/sound UI transitions, found and fixed sample-party and Demo-teardown restoration defects, and retained explicit limits on combat and display coverage.

## Still to do

- Verify actual-game screen-edge placement and scaling, XP artwork, minimap shapes/title/close button, party alignment and buff wrapping.
- Visually verify translated text fit and native-nameplate DoT alignment in real combat.
- Test compatibility with other addons in the live client.
- Stationary native-client verification is now authorized. Keep the character still and do not require the owner to demonstrate gameplay. Active combat and multiplayer checks remain pending until direct evidence exists. No documented headless game renderer has been established.
- Track exact results and remaining coverage in [UI verification](ui-verification.md); do not treat a screenshot from one viewport as verification of every display.

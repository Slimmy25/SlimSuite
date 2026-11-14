## Done

- Fixed the nameplate, native restoration, profile import, absorb overlay, sound and diagnostic defects from the initial review; published those fixes as version 1.31.
- Consolidated element metadata into a shared registry for native ownership, setup order, movable elements, feature flags, companions and display anchors.
- Made Enabled/Disabled/Default authoritative for replacement rendering and legacy settings transitions; retained compatibility reads for older saves.
- Split setup into focused onboarding, settings, editor, unit-frame and window modules.
- Changed profile autosave to take snapshots after edits, with a logout flush; idle polling no longer copies layouts.
- Tightened mock APIs and numeric geometry checks; added actual upstream Lua 5.0.3 compilation to CI.
- Consolidated translations into validated dictionaries. English, Spanish, French, German, Portuguese and Italian each cover all 363 dictionary keys. Added language selection and translated dropdown choices.
- Made settings rows grow for wrapped translations without shrinking the font.
- Added optional native-nameplate boss/guardian DoT attachments using documented timing/projection data.
- Replaced cache-disappearance sounds with the documented opened-cache counter, AZS_RUN.ck.
- Confirmed that the documented party data lacks shield totals; teammate values remain conditional on a real client absorb API.
- Passed 37 behavioral scenarios and 10,000 randomized UI actions. These are mock-client checks, separate from actual Lua 5.0 compilation.
- Included the refactor and encounter-bar DoT placement changes in version 1.32.

## Still to do

- Verify actual-game screen-edge placement and scaling, XP artwork, minimap shapes/title/close button, party alignment and buff wrapping.
- Visually verify translated text fit and native-nameplate DoT alignment in real combat.
- Test compatibility with other addons in the live client.
- Live visual checks remain unverified because desktop control was stopped and must not interrupt the user. No documented off-screen game test mode has been established.

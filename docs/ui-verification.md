# Native UI verification

## Purpose and scope

Prove that the actual client draws and restores SlimSuite correctly. A mock can check state and geometry logic; only the native renderer can establish texture masks, font metrics, mouse hit areas, clipping and real frame interactions. Every result records which kind of evidence supports it.

The current testing rule is stationary pregame verification. Do not ask the owner to play through runs or demonstrate features. Use addon samples where useful, label them as samples, and keep the real run clock at zero. Combat and multiplayer cases without direct evidence remain pending. Achievements, treasure-choice work and audible mix evaluation are deferred.

## Evidence and acceptance

For each test record the build/revision, client executable hash, actual window pixels, UIParent bounds and effective scale, OS display scaling, language, loaded addon set, profile/mode and reproducible steps. Record expected and observed behavior, a screenshot or native measurement, new error messages, and the final disposition: passed for this configuration, failed, blocked, or not run. Preserve a baseline and repeat a failed case after its fix.

A passing frame rectangle does not prove every texture fits it. Screenshots must also be inspected. Samples do not prove real enemy projection or multiplayer data. A saved-layout test is not a fresh-install test. An installed addon is not necessarily loaded. Physical pixels, UI units and OS scaling are separate measurements.

## Acceptance matrix

| ID | Exercise | Pass condition | Stationary approach / remaining dependency |
| --- | --- | --- | --- |
| UI-01 | Load and idle | No new Lua errors; no repeated work corrupts state | Compare baseline error identities, timestamps and repeat counts, not just total entries |
| UI-02 | Setup → Demo → setup → Done | Only enabled elements preview; green handles return correctly; samples disappear afterward | Native sample transitions, plus no-party/no-target cleanup |
| UI-03 | Move to every edge and corner, resize down/up | Actual content can reach the screen edge; text/art stays within intended bounds; no inaccessible grip | Native drag and small-size screenshots; numerical bounds are supporting evidence |
| UI-04 | Round/square and transparent minimaps | Correct mask/title/close styling; zoom/moon/buttons stay reachable; no clipped border controls | Inspect all four shape/transparency combinations; confirm button input separately |
| UI-05 | Action art and XP | Artwork aligns; border toggle works; demo fill cycles smoothly to 100 and back | Native samples and screenshots at several fill points |
| UI-06 | Player/target layouts and mirror | Exactly one player; native target hides with no target; sizes/distances stay consistent | Stationary target samples; real hostile click-targeting remains separate |
| UI-07 | Party orientations and self inclusion | Portrait alignment, member spacing and aura allocation remain correct; no phantom members after restoration | Samples cover layout only; real joining/leaving and multiple helpers need a party |
| UI-08 | Auras at minimum and normal widths | Direction settings work; two-row wrapping and durations fit; no neighboring overlap | Sample wrapping plus real supplied aura evidence when available |
| UI-09 | Stats/build/tooltips | Readable bounded content; independent row preferences survive; deferred item footer stays inactive | Pregame totals and tooltip samples; no fabricated stats |
| UI-10 | Chat resize and native restoration | Tabs/edit box align and work; original layout and filters return correctly | Native UI plus state/export comparison |
| UI-11 | Encounter markers, DoTs and nameplates | Markers and DoTs remain visible at opposite ends; native/modern plates align with actual units | Samples for layout; real moving enemies/projection and click targeting remain pending |
| UI-12 | Combat text | Normal hits remain; rows/motion stay inside bounds; quiet gaps do not reset insertion | Mock sequences and native samples; actual combat density remains pending |
| UI-13 | Enabled / Disabled / Default and module pause | Correct custom/native visibility; no leftover samples; retained settings resume exactly | Compare native frames, saved layout and pause snapshot through each transition |
| UI-14 | Profiles, reload and display return | Immutable templates stay intact; edits autosave; returning to original display does not accumulate drift | Isolated profile copies and before/after exports; reload with preserved saves |
| UI-15 | Sound controls | Play glyph is legible; pause-style control appears only with real stop support; queued/playing states are distinct | Native icons and transport scenarios; audible mix is out of scope |
| UI-16 | Languages | Every menu fits at normal readable font size; proper game names remain intact | Six-locale mock coverage plus per-language native screenshots |
| UI-17 | Other-addon compatibility | No duplicated owners, stolen anchors/tooltips or blocked clicks; teardown works in both load orders | Clean baseline, one addon at a time, then an explicitly recorded combination |

## Display coverage

Start with the actual primary display and saved layout. Next use real client window modes at 1920×1080 and 1280×720, then a resizable intermediate window. Cover 4:3, 16:10, 21:9 and 32:9 only when the client/display can actually present them. Test normal and an alternate supported UI scale, then return to the original configuration and compare saved anchors/sizes. Do not resize UIParent in a mock and report that as a physical-display test. Never invent engine modes or alter monitor settings merely to fill the table.

## Compatibility order

1. SlimSuite alone, existing layout and isolated fresh configuration.
2. Azeroth Stats enabled, checking meter windows, tooltips and restored native HUD ownership.
3. Each actually installed UI modifier separately, then combinations the owner uses.
4. Repeat module pause/resume and reload in the exercised combinations. Record load order and addon versions; do not declare broad compatibility from one screenshot.

Do not enable, disable or update unrelated addons without the task's authorization. A disabled installation provides no compatibility evidence.

## Current native run: November 15, 2026

The requested desktop client was exercised at 2560×1440 pixels with an existing saved layout. It reported UIParent-space screen bounds of approximately 1517.037×853.333 and root effective scale 0.9. Ten scheduled observations covered baseline, setup, sample Demo, square, round, transparent map, UI module off/on, sound settings and restoration. Every sample reported phase `ready` and run clock 0. Private screenshots and native measurements are retained outside the repository; they are not release assets.

Native visible movable-frame rectangles were within the measured screen bounds in those observations. The round/square map, borderless rendering, setup handles, sample presentation and white preview play glyphs were observed. This does not establish every child texture, button hit area, resolution, language or other-addon combination.

A native defect was found: choosing Default during UI module pause could unconditionally show empty party frames containing sample names. The fix respects native party/target existence before showing those frames. The focused native retest confirmed the sample party was visible during Demo and hidden after module off, module on and restoration. A second defect allowed Demo-hidden setup menus to reopen after teardown; setup now stops Demo before hiding its menus. The final native sequence returned to a clean stationary layout, and regression checks cover the teardown order.

The pre-existing error log contained an older ChoiceHUD comparison error with a fixed historical timestamp and repeat count; those did not increase through the UI transitions. The initial temporary QA helper used a client-restricted save-registration function; that helper call was removed before the successful sequence. Temporary QA instrumentation is not shipped.

Not yet established: native edge dragging at every corner, minimum-size child containment for every element, all display modes and UI scales, full six-language native fit, real party behavior, actual combat/nameplate/DoT projection, and compatibility with other enabled UI addons. These remain explicit pending rows rather than inferred passes.

## Completion rule

Close a row only for its tested configurations. Fix reproducible failures and rerun the affected transition; broaden only where new evidence requires it. Preserve user settings and historical error logs, remove temporary QA hooks, and keep screenshots/raw user data private. Release only through the normal version/check/release process when a push is requested.

### Final validation for the local changes

- All 54 canonical behavioral scenarios passed using the actual harness with Lua 5.3 through Lupa, including the five non-English locale variants.
- Block balance, stale names, load order, shared toolkit and legacy-Lua static checks passed.
- All 33 production modules compiled with actual Lua 5.0.3. The six locale dictionaries cover 517 keys each. All 19 audio assets passed the existing measurement checker; no audible evaluation was performed.
- The final five native observations (baseline, sample Demo, module off, module on and restoration) all remained in `ready` with run clock 0. The historical log retained its single entry with the same timestamp/count; no new runtime error was recorded in this final sequence.
- Current tested executable SHA-256: `8fa6dd6107286ff30ac1181da641f4f717753917db0076d484ef525d8a3caca0`.
- Temporary QA code was removed from the installed addon and manifest. Original saved settings were restored byte-for-byte before normal startup; installed production files were compared with the checkout. Release state is tracked in CHANGELOG.md; these results describe the pre-release candidate.

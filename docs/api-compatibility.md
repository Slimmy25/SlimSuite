# Client API decisions

The supplied `addon_docs(3).md` and the installed client's embedded addon Lua were inspected on November 14, 2026. No new game CVar or guessed API signature is required by these changes.

- **Confirmed cache opens:** the documented `AZS_RUN.ck` field counts opened caches. The tracker establishes a baseline per `AZS_ZONE.run` (or the meter context's `runId`), plays once when the counter increases, and resets its baseline on a new run or counter decrease. It does not infer opens from `AZS_CHESTS` removals. A missing counter produces no sound.
- **Enemy DoTs:** `AZS_GetDebuffs(unitId)` documents boss/guardian debuffs with `icon`, `remaining`, `duration`, `stacks` and other fields. Native and modern attachments use that data and documented world anchors/projection. The native attachment draws no replacement health/name body. Ordinary enemy DoT timings are not invented when the API does not supply them. The feature is optional.
- **Shields:** `AZS_RUN.sh` is the local hero's aggregate absorb value. The documented party table contains meter data, not teammate shield totals. `SS.AbsorbAmount` therefore returns unknown for teammates unless the client provides `UnitGetTotalAbsorbs`. It does not label damage/healing totals as shields or assign an aggregate shield to an individual buff.
- **Compiler:** `tools/check-lua50.py` builds the upstream Lua 5.0.3 compiler from its SHA-256-pinned source archive and parses each untouched production module in the manifest. Behavioral scenarios still use the explicitly mocked Lua 5.3 client; these are separate checks.
- **No off-screen renderer established:** no documented headless/off-screen UI test mode was found in the available client material. No hidden gameplay session, desktop input injection or live-game rendering claim is made. The user's request to avoid desktop interaction takes priority over completing visible-client checks.

Live verification remains needed for physical screen edges, native artwork/masks, translated text fit, real combat DoT alignment and other-addon interactions.

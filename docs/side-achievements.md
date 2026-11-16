# Unofficial side achievements

CURRENT STATUS: WIP. Hidden from hub, settings and setup. No progress collection, achievement awards, Stats reads, or fallback observations run until SS.ACHIEVEMENTS_WIP is explicitly removed in code. Existing progress is retained untouched. The descriptions below document the dormant framework.

These are local fun objectives, separate from the game’s real achievements and rewards. The hub and Gameplay menus open the achievement list. An optional Side achievements button can be positioned/resized in setup; its display is independent of progress tracking. Gameplay module Off pauses new tracking. Progress and earned dates live in SlimSuiteAchievementsDB, separate from HUD profiles and layout resets.

Native counters use the creator addon_docs(3).md AZS_RUN contract: kills, bk, gk, ck, ge and dealt. Observed ready/start boundaries permit counting the first sample; joining mid-run starts cumulative tracking from the first observed sample. Per-run high-water marks prevent repeated polling/reloads from adding the same cumulative counts. Counter regressions do not fabricate progress. PLAYER_DEAD and downed/revived banners observe personal deaths with per-life deduplication. Final victory is counted once per observed run; Heroic uses AZS_ZONE.heroic, never difficulty multipliers.

Starter goals cover cumulative kills (1,000 / 10,000 / 100,000), 25 deaths, 25 bosses, 50 guardians, 100 caches, 10,000 earned gold, 10 wins, a Heroic win, and single-run kills/damage. Return the favor is explicitly pending: AZS_GetRevive exposes in-progress revival and who is reviving you, not confirmed completed revives credited to each player. No reward is guessed from bar disappearance.

## Optional Azeroth Stats integration

Reviewed [Maidenquinn/AzerothStats InteropExport.lua](https://github.com/Maidenquinn/AzerothStats/blob/main/AzerothStats/InteropExport.lua) on 2026-11-15. Use only LatestRetainedRunId and ExportRetainedRunV1, schema 1.0.0. Read-only; never mutate its database, import its code, or sum its counters into our native totals. On opening our menu, the latest retained, completed, explicitly non-partial run can award effective-healing, damage and peak-DPS goals. Missing/unavailable metrics never become zero or proof. These goals disappear unless the addon is loaded and exposes the supported interface, even if previously earned. Older versions lacking that interface remain harmless and unsupported. Retained history other than the latest run is not scanned.

## Extending the catalog

SS.RegisterSideAchievement(id, title, description, metric, goal, source) adds definitions. Stable IDs preserve earned progress as wording evolves. Sources are native, stats or pending. New metrics require a verified collector; a definition alone cannot invent data. There is no server synchronization, gameplay reward, or modification of real achievement state.

## Final boss audio capability

The creator API explicitly exposes AZS_BANNERS kind=finalboss with id/name, AZS_UNITS kind=final with spawn id, and AZS_SCHEDULE final=1. Future per-boss sound mapping can use those confirmed arrival identities with per-spawn deduplication; name-only matching is unnecessary. This task establishes feasibility; it does not assign songs to bosses without the user’s selections.

## Fallback evidence framework

SS.RecordSideObservation(metric, sequence, amount, confidence, runId) accepts only registered metrics and their declared evidence class. A strictly increasing per-metric sequence deduplicates observations and rejects out-of-order updates. A run mismatch is rejected. Only the current run is retained, bounding storage by the fixed metric catalog. SS.SideObservation returns both value and evidence, never an unlabelled fact. Unsupported metrics and non-finite numbers are rejected.

The initial templates are observed near-complete revive attempts and self-reported revive credit/received revives. These do not award the pending Return the favor achievement. They cannot establish authoritative completed revives. The sampler is dormant while WIP. Future modules can add local spell/cooldown or health observations only with similarly explicit limits.

Possible future fun objectives: reach a personal damage record with a racial; survive a close call below 10% HP; open several caches in a short interval; assist several revives without being downed. Health/time/counter objectives can use confirmed samples. Exact revive credit, dodged mechanics and killing blows need stronger evidence or must remain labelled observations. No chat scraping or disappearance heuristic is treated as proof.

## Final-boss soundtrack implementation

SlimSuiteFinalBossSounds.lua catalogs the twelve finals from the local Guide Zones & Bosses section. Final-boss classification is native (finalboss banner or final unit), never name-only matching. Guide names provide per-boss menu overrides; unknown/localized names still receive the global selection. Selections cycle Use global soundtrack / Megalovania / Off. Arrival playback is once per named final per observed run, seeded silently after reload. The track is optional and uses PlaySoundFile, retaining the documented legacy client limitation that long MP3s cannot be stopped early. No game music setting is changed.

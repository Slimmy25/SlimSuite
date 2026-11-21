# API capability review

Reviewed against the supplied creator API documentation and the current native client on November 15, 2026. Read-only inspection and native capability checks are evidence; proposals below are not APIs that already exist.

## Reviving teammates

| Evidence | Available now | What it establishes |
| --- | --- | --- |
| `AZS_GetRevive()` / `AZS_REVIVE` | `down`, `share`, `by`, `reviving`, `rshare` | Whether you are down, the friend helping you, your current revive target and progress. A progress reset does not prove completion. |
| `AZS_GetDownedPartyMembers()` | Stable hero `id`, display name, world position, run/map/space identity and the current fall's `anchorId` | Where a downed teammate can be helped, including instances. Names are display values, not stable identifiers. |
| `AZS_ProjectWorldAnchors()` | An expired downed anchor can report `reason="revived"` | That particular fall ended by revival, rather than departure, expiry or run end. This can establish a teammate was revived when the exact anchor was previously observed. It does not name every helper or allocate credit. |
| Native `revived` banner | Local player stands again; its name field is empty | Your own revival. It is not a completed teammate-revive event credited to you. |

This makes reliable downed-teammate markers and revive progress possible today. A future non-achievement co-op helper could preserve the anchor for the current fall and distinguish confirmed revival from disappearance. It must reject cross-run/space samples, never treat an empty/not-ready list as proof, and distinguish completion from who helped.

Completed **personal revive credit** remains unavailable. Creator patch notes also describe multiple simultaneous helpers, so the single `by` name is not a complete contributor ledger. Do not infer sole credit from being near the body or from `rshare` approaching 1. Achievements and fallback observations remain inactive; this review does not turn on any tracking.

A creator extension could expose a completion event containing an event ID, run ID, downed hero ID, fall/anchor ID and explicit contributor IDs or the game's credit decision. This is a proposed contract, not an implemented call.

## Teammate and per-buff shields

- `AZS_RUN.sh` is the local hero's current aggregate shield. It already supports the local absorb overlay and Stats HP display.
- `AZS_PARTY` / `AZS_GetPartyMeter()` contains damage statistics, not current teammate health/shields. Healing or `absorb_consumed` meter totals measure past activity and cannot reconstruct shield capacity remaining now.
- The inspected client does not expose `UnitGetTotalAbsorbs`. SlimSuite retains its conditional adapter for a client that actually provides it.
- `AZS_BUFFS` contains spell IDs and remaining time. A tooltip may describe a shield, but the documented data has no typed current per-buff absorb field. Casting formulas cannot account reliably for stacking, consumption, refreshes and multiple sources; localized tooltip text is not a stable numeric contract.

Teammate totals need an authoritative query or synchronized table keyed by stable hero ID. Per-buff values need current absorb remaining plus source/aura-instance identity and removal/refresh semantics. Until those exist, unknown values stay unknown. No fabricated bars or totals are introduced.

## Pregame boss locations

`AZS_SCHEDULE` supplies index, arrival time, name, final flag and state. It does not supply spawn coordinates. Live world anchors provide current positions for entities that exist; they do not promise a future boss's spawn position. Existing cache/lair coordinates can be shown only in the matching run/map/space. Zero is a valid coordinate.

A useful creator extension would add an explicitly available planned spawn position, stable encounter identity and run/map/space fields, with a revision if the spawn plan changes. Reusing a previous run's spawn or placing a timed boss at the center of the map would be misleading.

## Localized final-boss overrides

Names supplied by the game are display values and may be localized. The addon now resolves an unknown final name through the documented `AZS_ZONE.zone` key to the existing twelve-entry guide catalog. Existing per-boss settings keep their keys. Exact known guide names remain supported, and an unknown zone/name falls back to the global track. Canonical identity is also used for banner/live-unit deduplication and reload seeding.

This resolution is used only after native `finalboss`/`kind="final"` classification. An ordinary same-name enemy cannot become a final boss through the zone lookup. No translations of boss names are invented.

## Preview interruption

The inspected client exposes `PlaySoundFile`, `PlayMusic` and `StopMusic`, but no `StopSound` or `PauseSound`; the native QA sample also reports those globals as nil. Sound previews therefore play on the music channel (PlayMusic / StopMusic) so they can be paused and replaced; the game's music pauses meanwhile. With music turned off or at zero volume, previews fall back to the effects channel and its one-at-a-time queue.

Where an actual stop handle exists, a new preview stops the previous one first. A stop error or explicit failure keeps the current preview active. Otherwise only the latest request is queued until the current tracked clip finishes. Selecting the active clip cancels a pending replacement. The queue prevents deliberate overlap; it is not true pause/resume or real-time native playback detection.

True pause/resume requires a client API returning a preview handle and supported pause/resume/stop operations, with defined completion and channel behavior. That change belongs in the client; an addon cannot manufacture the missing capability.

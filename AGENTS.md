# SlimSuite project instructions

- Addon changes belong to Slimmy25/SlimSuite, not the launcher repository.
- When the user requests a push, increase the addon version by 0.01, push to main, and verify the automated release and ZIP.
- Every newly supplied audio asset must be equalized/normalized before release. Use `tools/normalize-audio.py` against the pinned target in `docs/audio-normalization.json`, retaining peak limiting and endpoint fades. Run `tools/check-audio.py`; do not ship unmeasured MP3s or change the loudness target without a user request.
- Match-loss sounds are exclusively for confirmed final defeat/the final death-log screen, never ordinary player or teammate deaths. Keep death, teammate, loss, victory and start-song selections distinct.

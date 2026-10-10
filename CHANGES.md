# AutoAreaLoot 1.3.0 – changes

## Added in 1.3.0
- **Loot speed presets** (`safe` / `normal` / `fast`): `/aal speed <name>` and a Speed button in the settings panel. Saved per account. `normal` is bit-for-bit the previous timing. `fast` cuts death->scan from ~0.25 s to ~0.10 s, stop->scan from ~0.15 s to ~0.08 s and the settle window after a successful scan, so the next pull starts ~0.15 s sooner.
- Corrupt or unknown saved speed values fall back to `normal`.
- `/aal status` shows the current speed. Settings panel is 24 px taller to fit the button.
- `tests/speed.lua`, plus invariant counting (no scan while moving, casting, dead or with a manual loot window open) in the fuzz harness.

## Regression check (1.3.0)
`normal` vs original: 300 random event streams, 23,236 steps, 0 differing lines. All three presets: 300 streams each, 0 invariant violations.

# AutoAreaLoot 1.2.0 – changes

## Fixed (found by edge-case testing of 1.1.0)
- Lost spellcast stop event left looting blocked until `/reload`. Now expires after 30 s when no cast/channel is active.
- Lost `PLAYER_CONTROL_GAINED` left looting blocked until `/reload`. Now expires via `HasFullControl()` (if present) or after 90 s.
- A request queued while dead/ghost was not serviced after resurrection unless you stopped moving. Now serviced on `PLAYER_ALIVE` / `PLAYER_UNGHOST`.

## Added
- `/aal help`, `/aal clear`, `/aal death|stop|combat on|off`; richer `/aal status`.
- `tests/` mock-client harness (baseline, adversarial, differential fuzz).

## Regression check
Original and 1.2.0 were fed identical random event streams (300 seeds, 23,236 steps): every scan, pending-request state and logged loot/money total matched step for step. Differences only appear in the intended fixes above.

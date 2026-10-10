# AutoAreaLoot

AutoAreaLoot automatically loots nearby corpses when it is safe to do so. It is event-driven (no polling loops for looting) and shows a session loot log.

**Version 1.3.0** – selectable loot speed, self-healing safeguards, resurrection handling and new `/aal` commands. See [CHANGES.md](CHANGES.md).

## Behavior

- Loots nearby corpses when an NPC death event fires
- Ignores Nampower death events whose units are clearly beyond loot range
- Individually configurable death and movement-stop triggers
- Optional in-combat looting, enabled by default
- Coalesces blocked triggers into one pending loot pass
- Runs one final pass after combat when a combat-time trigger occurred
- Avoids interrupting manual loot windows
- Preserves new death requests received during an active loot walk
- Coalesces same-area movement stops into the active walk, while preserving one follow-up after moving into a new loot area even if the active walk succeeds
- Limits same-area movement-stop scans to one every 0.5 seconds, but permits an immediate scan after moving at least five yards into a new loot area
- Waits 0.15 seconds after movement stops and cancels the attempt if movement resumes; death requests received while moving remain queued for that stop
- Detects actual player speed so RMB strafing, jumping and other displacement do not depend on forward/back movement events
- Uses a bounded latency-adjusted settling period after successful walks, avoiding rescans while loot is still being delivered
- Confirms item loot from the player's localized loot messages and filters it against the corpse scan
- Uses corpse GUIDs to prevent repeated scans from creating duplicate live loot-confirmation expectations
- Shows money totals and optionally combines matching item rows
- Shows the newest 500 loot events first with timestamps when rows are uncombined; keeps full-session combined item and money totals independently of that display limit
- Item tooltips on hover; the loot log is resizable and remembers its size and position; it can open automatically on login or `/reload`
- Automatically uses a built-in pfUI theme when pfUI is loaded
- `/aal debug` opens a bounded, copyable diagnostic trace without flooding chat

### New in 1.3.0: loot speed
The addon cannot speed up the corpse walk itself (that runs inside ClassicAPI), but it controls how long it *waits* around a scan. Three presets change those waits:

| Preset | Death -> scan | Stop -> scan | Next pull after a successful scan |
|---|---|---|---|
| `safe` | ~0.35 s | ~0.25 s | ~0.50 s |
| `normal` (default, identical to 1.1/1.2) | ~0.25 s | ~0.15 s | ~0.35 s |
| `fast` | ~0.10 s | ~0.08 s | ~0.20 s |

Change it with `/aal speed safe|normal|fast` or the **Speed** button in the settings panel. `fast` saves roughly 0.15 s per trigger, which adds up in AoE pulls. On a high-latency connection use `normal` or `safe`: if a corpse is not yet lootable when the scan runs, that scan comes back empty and the corpse is picked up on your next stop or kill.

### Added in 1.2.0
- **Stale cast flag self-heals** – if a spellcast stop event is ever lost, the "player is casting" block expires after 30 s once the client confirms nothing is being cast or channelled. A real long channel (for example a bandage) is never interrupted.
- **Stale control-lost flag self-heals** – if "control regained" is ever lost, the block ends as soon as `HasFullControl()` reports control (when available), or after 90 s otherwise. A genuinely stunned or feared player stays blocked.
- **Resurrection servicing** – a loot request queued while you were dead or a ghost is now serviced on `PLAYER_ALIVE` / `PLAYER_UNGHOST`, instead of waiting for the next movement stop.
- **New slash commands** – `help`, `clear`, and `death|stop|combat on|off` (handy for macros). `status` now also reports whether ClassicAPI loot and Nampower death events were detected.

## Commands

| Command | Action |
|---|---|
| `/aal` | Open or close the settings panel |
| `/aal on` / `/aal off` | Enable or disable looting |
| `/aal death on\|off` | Toggle the death trigger |
| `/aal stop on\|off` | Toggle the movement-stop trigger |
| `/aal combat on\|off` | Toggle looting in combat |
| `/aal speed safe\|normal\|fast` | Set loot speed (`/aal speed` shows it) |
| `/aal status` | Show settings and client-mod detection |
| `/aal log` | Toggle the loot log |
| `/aal clear` | Empty the loot log |
| `/aal debug` / `debug off` / `debug clear` | Diagnostic trace |
| `/aal help` | List commands |

## Client mods

| Client mod | Required? | Used for |
|---|---|---|
| [ClassicAPI](https://github.com/brues-code/ClassicAPI) (v1.12.7) | **Required** | `C_Loot.LootAllCorpses`, `C_Loot.IsScanInProgress`, `C_Loot.GetLastScanResults`, the `LOOT_SCAN_COMPLETED` event, `C_Timer.After`, `C_EventUtils.IsEventValid`, `UnitPosition`, `UnitDistanceSquared`, `GetUnitSpeed`, `UnitCastingInfo` / `UnitChannelInfo`, and its Lua 5.1 syntax / `string.match` support. The addon prints a chat message if `C_Loot.LootAllCorpses` is missing. |
| [Nampower](https://github.com/brues-code/nampower) | Optional, recommended | `UNIT_DIED` event for reliable, range-filtered death detection. Without it the addon falls back to `CHAT_MSG_COMBAT_HOSTILE_DEATH` and tells you so. |

SuperWoW, UnitXP_SP3, VanillaHelpers and WeirdUtils are not used.

## Installation
Put the `AutoAreaLoot` folder in `Interface\AddOns\`. The folder must also contain the existing `Fonts\PTSansNarrow.ttf` and the `Icons\` textures (`Circle.tga`, `SizeGrabber*.tga`) that the loot log uses. If you update an existing install, keep those folders.

## Testing
`tests/` contains a mock WoW 1.12 + ClassicAPI environment that runs the addon's real code under a plain Lua 5.3+ interpreter (for example `texlua`, `lua5.3` or `lua5.4`):

```
cd tests
lua harness.lua ../AutoAreaLoot.lua -v scenarios.lua     # 15 baseline scenarios
lua harness.lua ../AutoAreaLoot.lua -v adversarial.lua   # edge cases: stuck flags, resurrection, commands
lua harness.lua ../AutoAreaLoot.lua -v idle_alive.lua    # resurrection event edge cases
lua harness.lua ../AutoAreaLoot.lua -v speed.lua         # speed presets: timings, persistence, invariants
SEEDS=300 lua harness.lua ../AutoAreaLoot.lua x fuzz.lua # randomized event streams (diff two versions)
SPEED=fast SEEDS=300 lua harness.lua ../AutoAreaLoot.lua x fuzz.lua  # same, with a speed preset; prints invariant violations
```
The mock replaces the client, so these tests prove the state-machine logic, not in-game behaviour.

## Known limitations
- `PLAYER_ALIVE` / `PLAYER_UNGHOST` handling, the stale-flag timers and the speed presets are verified in the mock only, not in-game. The mock cannot tell how soon a real server flags a corpse lootable, so try `fast` and fall back to `normal` if kills get missed.
- The death fallback without Nampower cannot filter by distance, so far-away deaths may trigger a harmless empty scan.

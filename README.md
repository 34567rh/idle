# The Idle Mines recovery

This is a playable-core reconstruction from the supplied client-exported place. The original has 280 script containers, with the game scripts containing commented bytecode rather than runnable source; no original server implementation was saved. This project preserves the authored art and UI and supplies new server and client code.

**Built place:** `build/The_Idle_Mines_Recovered.rbxl`. Open this file in Studio to test the rebuild. The original copy at `assets/The_Idle_Mines.original.rbxl` is preserved; SHA256 `ed252943537300327a9f8217293f50b63553897f144f09ea9e0f8c9dfc344a08`.

## Implemented core

- A separate mine per player; server-calculated orbit hits, rewards, mine refill, levels, and clear bonuses.
- Manual movement or an Idle toggle that moves into orbit reach of remaining rocks.
- Rolls using the recovered 200-pickaxe catalogue and original art. The first roll gives Coal; later rolls use rarity weights and luck. This is a reconstructed probability model, not a claim to recover the original roll algorithm.
- Inventory, owned-copy equipment validation, Equip Best, auto-equip, and coin-earned slots.
- Six coin upgrades: orbit speed, movement speed, money, luck, roll speed, and clear bonus.
- Rebirth with a level requirement; keeps pickaxes and slots, resets coins and upgrades, and increases permanent luck.
- Offline coin claims and ProfileStore session saves; owner-only Replica data and rate-limited Packet commands.
- The authored HUD, roller, loadout, upgrade tree, rebirth, settings, index, and offline claim panels.

Gear, potions, paid purchases, trading, ranks, chests, races, throwing, and PickDrop are not rebuilt. Their controls are hidden. Balance for mine HP, XP, upgrade limits, and offline rewards is new where the original logic could not be recovered. Existing live-game progress is unavailable; saves use `IdleMinesRecovery_v1`, with a separate `_Studio` store for tests.

## Checks and build

Cloud tools are installed in `/workspace/roblox-tools/bin`: Rojo 7.7.1, Wally 0.3.2, StyLua 2.5.2, Selene 0.32.0, Lune 0.10.5, and luau-lsp 1.69.0. `scripts/install-tools.sh` installs those pinned Linux x86_64 binaries, verifying downloaded checksums. Official type definitions are downloaded and checksum-checked by `scripts/prepare.py`.

```bash
source /workspace/roblox-tools/activate.sh
cd /workspace/idle
./scripts/check.sh
```

The check verifies formatting, generates the Rojo sourcemap, analyzes source against pinned Roblox types, runs 20 behavioral tests, and builds/reopens the complete binary place. Dependencies are vendored at fixed upstream revisions; this project does not require Wally package downloads. Selene is installed, but the project uses luau-lsp for full Roblox type and API analysis.

On Windows, install the equivalent tools on PATH and Python 3, then run `./scripts/check.ps1`. The PowerShell wrapper is provided for convenience; it has not been executed in this Linux environment.

Rojo alone builds **code only**. The complete game combines that output with the preserved binary assets:

```bash
rojo build default.project.json --output build/code.rbxlx
lune run tools/BuildPlace.luau
```

For iterative development, open the recovered place in Studio and connect the Rojo plugin to `rojo serve default.project.json` on the same machine. Cloud source editing and builds work independently; connecting a local Studio to cloud Rojo requires a suitable connection. No Studio control or Roblox engine is available in this cloud session.

The architecture follows the supplied [game boilerplate](https://github.com/frrazer/roblox-game-boilerplate/tree/00613ca10e8b0fe64c2fd567869ab1c4700af094): ordered Lifecycle startup/cleanup, services for rules and state, client controllers and per-panel UI modules, Packet commands, Replica, and DataService-owned ProfileStore. See `AGENTS.md` for conventions and `THIRD_PARTY.md` for dependency provenance.

## Studio playtest checklist — pending

Offline tests check game rules and bind the actual saved GUI trees with mocked events. They do not execute Roblox physics, rendering, replication, asset permissions, or real DataStores. None of the following engine checks has been completed yet.

1. Open **The_Idle_Mines_Recovered.rbxl**, then Play. Expect a character, one mine, the HUD, and rotating pickaxes. Check Output for errors; bootstrap prints readiness messages.
2. Move with WASD through the mine. Blocks should break and money should increase. Turn **Idle** on and verify that a mine clears and refills, including its last rock.
3. Tap **Roll**. The first pick should be Coal, appear in Loadout, and auto-equip. Repeated taps must respect the server cooldown. Toggle Auto Roll and check that it stops when disabled.
4. Buy an affordable upgrade and a second slot. Check the charge, speed/damage behavior, Equip Best, and inventory copy limits. Open Settings and Index; verify the labels match your current data.
5. Reach level 20 and rebirth. Coins and upgrades reset; owned picks and slots remain. The next requirement is level 28.
6. Use Studio's Server & Clients mode with two players. Each should spawn in a separate mine and see only their own balance and inventory. Leaving should remove their mine.
7. With Studio API access disabled, expect a mock-save warning and progress to reset when Play ends. For real saving tests, publish a test copy and enable **Game Settings → Security → Enable Studio Access to API Services**. Rejoin to verify persistence and a single offline claim. Studio saves use the separate `_Studio` namespace.

Keep the Output log from any failed step. Asset ids belong to the saved place and their loading/permission behavior must be checked in Studio.

## Files

`src/server` contains gameplay and persistence; `src/shared/Config` contains recovered data and balancing; `src/client` drives the saved UI. `tools/BuildPlace.luau` creates the full game without changing the original. `build/recovery-report.json` records script replacement and asset checks. `build/test-results.json` records offline test counts.

The optional inspection helpers read the original and write ignored reports under `inspection/`. The bytecode reader is for static data inspection only; it never executes recovered bytecode. It needs the matching open-source Luau `Bytecode.h` at `inspection/Bytecode.h`, plus `InspectPlace.luau` output; it is not part of the build or checks.

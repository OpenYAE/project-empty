# YAE-dlls — repository guide

Reverse-engineering research project: a from-scratch C++20 re-implementation of the
DS2 engine (game "You Are Empty", 2006), plus the decompiled originals for reference.
**Game resources are treated as read-only** — never modify `.ds2*` asset files; reconstruct
missing behaviour in engine code instead.

## Layout

- `yae-engine/` — the new engine (C++20, SDL3, OpenGL 4.5, Jolt, Lua 5.4). Main work happens here.
  `src/` is the engine library, `app/` the thin executable, `tests/` the startup self-tests.
- `yae-game/gameres/` — original game assets (levels, models, scripts, textures). **Read-only.**
- `yae-game/documents_my games/YaE/` — what the original game writes to *My Documents*:
  engine/user configs, key binds + every authored cvar default, savegames, logs.
  **Read-only reference** — see `yae-engine/docs/UserFiles.md`.
- `c-files/`, `programs_extracted/` — decompiled original DLLs, for RE reference.
  **Not one build:** most are 2006-11-11, but `sv_game.dll`, `ds2kernel.dll`,
  `ds2NavSystem.dll` and `you_are_empty.exe` are 2019 rebuilds — this is a *community*
  release whose unofficial patches pulled in libraries from a later DS2 Engine version
  (adapted for another game). Behaviour found only in those four files may never have
  existed in the 2006 game — `engine.play_comics` is the known example.
- `scripts/` — analysis notes (e.g. `YAE_Architecture_Review.md` — a Phase-10 snapshot, outdated).
- `*.dll`, `*.exe` — original game binaries.

## Build & run

```bash
bash build.sh                       # cmake + ninja, RelWithDebInfo → yae-engine/build/yae-engine
                                    # (reconfigure with `cmake -B yae-engine/build ...` after adding new .cpp,
                                    #  since sources come from CMake file(GLOB_RECURSE))
bash run_level.sh -map med1         # run a level by stem or map dir (map10, gor, vdnh1, meat, …); tees to yae-engine.log
./yae-engine/build/yae-engine --level yae-game/gameres/maps/map10/med1.ds2 --root yae-game/gameres [--edf <f.ds2edf>]
./yae-engine/build/yae-engine --model <path.ds2md> --root yae-game/gameres   # single-model viewer
```

- `--level <path>` uses direct/CLI load (`loadLevelDirect`); campaign/transitions use `loadLevel` (by-name).
- Logs: `yae-engine.log` (run_level.sh tees), plus `yae-engine-test*.log`.
- **Self-tests** run at startup (`runSelfTests()`, `yae-engine/tests/`) and print `PASS`/`FAIL` to the log —
  grep `self-test` after any run to confirm core subsystems (EntitySystem index, Lua, Jolt, parsers).
  The last line is a total (`self-test summary: N/M passed`); one standing failure is known
  (`Jolt Physics`, a raycast against a map in a neighbouring repo). Cases live one file per domain
  (`CoreTests`, `EntityTests`, `UITests`, `AITests`, `RenderTests`, `LevelTests`, `PhysicsTests`);
  **run order is the explicit list in `tests/TestRegistry.cpp`** — some cases lean on state an
  earlier one left behind, so add new cases there as well as declaring them in `SelfTestCases.h`.

## Engine source map (`yae-engine/src/`)

`core` (Types/Logger/InterfaceServer) · `entity` (Entity, actors, doors, triggers, joints, ropes, FSM, I/O)
· `render` (GL4 renderer, shaders, post-process, decals) · `physics` (Jolt wrapper + coordinator, ragdoll)
· `scripting` (Lua 5.4 bindings) · `ai` (combat loop, goals, perception) · `game` (GameRulesYAE facade +
coordinators) · `assets` (`.ds2/.ds2md/.ds2cm/.ds2edf` parsers) · `audio` · `animation` · `navigation`
· `ui` (also the comics player) · `scene` · `resource` · `camera` · `input` · `platform`
· `video` (AVI cutscenes: decoder backend + player + preset resolution).

`GameRulesYAE` is the top-level facade; it delegates to coordinators (LevelLoader, WeaponCoordinator,
DebugCoordinator, PhysicsCoordinator, GameLuaBinder, PlayerController, NPCSpawner). Put new subsystems in
a coordinator, not the facade.

## Docs & skills

- `yae-engine/docs/Invariants.md` — coordinate systems, frame order, init/ownership, actor-activation rule. **Read this first.**
- `yae-engine/docs/LevelTestMatrix.md` — which level is the golden test for which subsystem.
- `yae-engine/docs/UserFiles.md` — the original's *My Documents* tree: configs, cvar defaults,
  key binds, save format. Check it before inventing a tuning constant.
- `yae-engine/docs/Phase29_Refactoring.md` — current refactoring status (supersedes `scripts/YAE_Architecture_Review.md`).
- `yae-engine/docs/console/` — developer-console docs.
- Skills `yae-codeguide` (auto-invoked when editing C++/Lua) and `yae-review` encode conventions & anti-patterns.

## Golden rules

1. **C++ = engine primitives, Lua = game logic.** Thin bindings; let Lua prototypes decide behaviour.
2. **Never modify game resources** (`.ds2*`). Compensate in code (see `physics::kCrane*` for the meat-crane case).
3. **Preserve the deterministic frame order** (see Invariants.md) — reordering breaks game logic.
4. Physically-sensitive changes: verify on **m02/meat** (crane/joints/ropes) — see LevelTestMatrix.md.

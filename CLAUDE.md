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
- `yae-game/ds2base.cfg` — the original's directory table (`game_save`, `screenshots`,
  `configsuser`, …), read at startup since Phase 32.7.3b: it is what every `FS_PATH_*`
  answer comes from. `$my_games$` resolves to `yae-game/my games/` (writable), never to
  the read-only `documents_my games/`. Changing where saves go is one line in that file.
- `c-files/`, `programs_extracted/` — decompiled original DLLs, for RE reference.
  **Not one build:** most are 2006-11-11, but `sv_game.dll`, `ds2kernel.dll`,
  `ds2NavSystem.dll` and `you_are_empty.exe` are 2019 rebuilds — this is a *community*
  release whose unofficial patches pulled in libraries from a later DS2 Engine version
  (adapted for another game). Behaviour found only in those four files may never have
  existed in the 2006 game — `engine.play_comics` is the known example.
- `yae-materials/` — community PBR catalog over the original textures (neutral JSON records,
  deterministic normal-map baking, exporters). AI generation is a first-class backend, not a
  late add-on — see `yae-materials/docs/GenerationPipeline.md` (one `MaterialGenerator`
  interface, bundles rather than single maps, `recipe` vs `lock`, faithful-by-default). Its `export/` and `baked/` are derived and
  gitignored: `npm run bake -- --all && npm run export-engine` rebuilds them locally. The engine
  auto-probes `<gameres>/../yae-materials/export/engine/catalog.yaemat`; `--no-materials-catalog`
  or `mat_catalog 0` loads levels vanilla. See `yae-materials/PLAN.md`.
- `scripts/` — analysis notes (e.g. `YAE_Architecture_Review.md` — a Phase-10 snapshot, outdated).
- `*.dll`, `*.exe` — original game binaries.

## Build & run

```bash
bash build.sh                       # cmake + ninja, RelWithDebInfo → yae-engine/build/yae-engine
                                    # (reconfigure with `cmake -B yae-engine/build ...` after adding new .cpp,
                                    #  since sources come from CMake file(GLOB_RECURSE); tests/ is listed explicitly)
bash build.sh --check               # build + gates: own-code warnings, self-tests, level smoke pass.
                                    # ~27 s, stops at the first failure. Run it before committing.
bash run_level.sh -map med1         # run a level by stem or map dir (map10, gor, vdnh1, meat, …); tees to yae-engine.log
./yae-engine/build/yae-engine --level yae-game/gameres/maps/map10/med1.ds2 --root yae-game/gameres [--edf <f.ds2edf>]
./yae-engine/build/yae-engine --model <path.ds2md> --root yae-game/gameres   # single-model viewer
```

- `--level <path>` uses direct/CLI load (`loadLevelDirect`); campaign/transitions use `loadLevel` (by-name).
- Logs: `yae-engine.log` (run_level.sh tees), plus `yae-engine-test*.log`.
- `bash build.sh --check` is the one command that answers "is the tree still good": it fails on a
  warning in `src/`/`app/`/`tests/`, on a self-test failure, on a file past its size budget
  (`scripts/size_budget.sh` — raise a ceiling on purpose, never by accident), or on a level that
  stopped loading cleanly. Without a display the smoke pass is reported as skipped, not silently
  dropped.
- **Menu/UI work:** `YAE_SKIP_INTRO=1` skips the 24 s logo so the main menu is up in ~4 s, and the
  `ui` console command drives it: `ui list` (21 screens), `ui show <widget>` opens one without
  clicking to it, `ui dump <widget>` prints the tree with config vs computed rects and `NO-MATERIAL`
  flags, `ui trace on` logs hit-tests. `YAE_CONSOLE` works in the menu too (no level needed).
  Reference shots of the original are in `yae-engine/tests/referenses-menu/`, ours in `ours/`.
- **Smoke test:** `bash scripts/smoke_levels.sh` (~30 s, needs a display) loads all 15 golden levels
  for 120 frames each and fails on any `[ERROR]` or on warnings that are new against
  `scripts/smoke_baseline.txt` (folded to message shape + count, since a lot of the originals'
  warnings are legitimate and never reach zero). A count that grew is only a failure when it both
  more than doubled and grew by 5+ — some warnings repeat on a timer, so ±1 between runs is noise.
  `--record` rewrites the baseline, `--frames N` runs longer, and naming levels (`… med1 meat`)
  checks a subset. The engine flag behind it is `--frames N`: run the real loop N times, then quit
  with 0, or 1 if anything logged `[ERROR]`.
- **Self-tests** run at startup (`runSelfTests()`, `yae-engine/tests/`) and print `PASS`/`FAIL` to the log —
  grep `self-test` after any run to confirm core subsystems (EntitySystem index, Lua, Jolt, parsers).
  The last line is a total (`self-test summary: N/M passed`).
  `./yae-engine/build/yae-engine --self-test` runs the suite **as a gate**: no window, no GL, no
  level, ~0.3 s, exit code 0/1 (`--root <gameres>` if not run from the repo root; the cases needing
  a GPU report `SKIP`). Use it before committing. Cases live one file per domain
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

Input routing: `app/AppEventRouter` owns the SDL event chain (console → video → comics →
cutscene → ESC/pause → screenshot → frozen guard → debug → gameplay). **Order is the contract** —
add a handler to that list, do not bury a new `if` inside one.

`GameRulesYAE` is the top-level facade; it delegates to coordinators (LevelLoader, WeaponCoordinator,
DebugCoordinator, PhysicsCoordinator, GameLuaBinder, PlayerController, NPCSpawner). Put new subsystems in
a coordinator, not the facade.

## Docs & skills

- `yae-engine/docs/Invariants.md` — coordinate systems, frame order, init/ownership, actor-activation
  rule, and **state that outlives a level** (per-level state goes on its object and is cleared in
  `unloadLevel()` — a function-local `static` can be neither reset nor saved). **Read this first.**
- `yae-engine/docs/LevelTestMatrix.md` — which level is the golden test for which subsystem.
- `yae-engine/docs/UserFiles.md` — the original's *My Documents* tree: configs, cvar defaults,
  key binds, save format. Check it before inventing a tuning constant.
- `yae-engine/docs/Phase31_Refactoring.md` — current refactoring status (supersedes Phase 25/29 docs
  and `scripts/YAE_Architecture_Review.md`).
- `yae-engine/docs/Phase32_MenuSettingsSaves.md` — menu/settings widgets, UI sound, menu video,
  console chrome, and the save system. 32.0–32.7 are done (saves: read the original's `.ds2gsf`,
  write our own; console `save list|dump|write|load`, and the authored Save/Load screens).
- `yae-engine/docs/SaveFormat.md` — the `.ds2gsf` savegame format, decoded and verified against the
  ten reference slots — including the per-object tail (entity I/O graph + each script's `io` table),
  which is what makes an original save **loadable** (Phase 32.7.6). `scripts/gsf_dump.py` implements it.
- `yae-engine/docs/Phase32_SaveAgentBrief.md` — the handoff brief for implementing the save system.
- `yae-engine/docs/MaterialSystem.md` — where materials are going: the engine does not parse the
  original `.mat` at all (268 authored templates; `classifyDecalMaterial()` hand-transcribes ~22
  name patterns and 19 of the 54 templates the golden levels use fall through to plain opaque).
  Answers "legacy or new format" with **one runtime `Material`, two dialects of one grammar, four
  override layers**, and explains why per-item uniforms — not `.mat`'s age — are what blocks
  compute/RT. Its work plan is `Phase33_Graphics.md`. Settled decisions live here:
  metal/rough (never spec/gloss), `metallic` is never inferred from `.mat`, and the shading-model
  switch is `.mat`'s own `material` field rather than a new flag. Phase 33.1 is **done**: the scene shaders now write MRT
  attachment 1 (view normal + linear depth), SSAO is on, and the same buffer is what DoF was
  missing. Read before touching material handling or `render/MaterialCatalog.h`.
- `yae-engine/docs/Phase33_Graphics.md` — the graphics work plan (33.1–33.9, five subphases before
  the playable release). Several subsystems turn out to be written and switched off, or half-wired:
  vertex colours are parsed and dropped, detail maps are parsed and unused (SSAO was one of these
  until 33.1 turned it on). **This is the current graphics tracker.**
- `yae-engine/docs/RTGL1_Integration_Plan.md` — GL stays the shipping renderer; RT is a gated
  experimental branch. Its Phase 1 (backend-neutral render scene) is what MaterialSystem.md builds.
- `yae-engine/docs/Phase34_FixMed1Map.md` — the twenty `med1` TODO items, one subphase each, with
  the root, the A/B and the self-test for every one that is closed. **The per-level pattern**: the
  campaign's remaining bugs are being worked level by level, and the entry point for a level is its
  phase doc, not `TODO.md`. Several roots found there are campaign-wide (decal scale, `play_sound`
  event-vs-state, authored command `parameters`, flare billboards, destroyed-entity models).
- `yae-engine/docs/Phase35_FixKolhozMap.md` — the same for `kolhoz` (both halves). **Done**: all
  fourteen items closed, so this is the worked example of the per-level method rather than an open
  tracker. Four of its roots were campaign-wide channels that were parsed and unused
  (`entities[…] = nil`, `on_damage_limit`, the weapon range window in metres, the `_all_edf`
  resolver preference); five more turned out to be engine-wide contracts nobody had stated — an
  animation owns its body's *collision*, an authored placement is a facing as well as a pose, an
  actor's idle pose can be authored per placement, and per-bone hitboxes have to follow the pose.
  Three reported items needed no fix at all and were closed by measurement; two plan hypotheses
  were built, measured and dropped. Both are the point: the phase docs record what was ruled out,
  not only what was changed.
- `yae-engine/docs/Phase36_FixMeatMap.md` — the same for `meat` and `meat_part2` (13 items, 11
  subphases). **Done** — eleven of the thirteen items closed with a named root, two measured and
  handed to the graphics tracker. Half of them were about *classes*, not about the level, so the
  fixes are campaign-wide: `Conveyor` pushes along its own local **X** (not +Y — and not because
  the box is long in X; 42 moving belts split 21 X / 21 Y), `shape = "point"` means a lift's
  collision comes from the whole model (`elev_meat_final` 10 of 11 boxes, not one corner post),
  `AnimationObject` is a class with three authored properties nobody read (93 unique placements),
  `BombEntity::postSpawn()` was a shadow of a non-virtual base method so **1910 bombs** never got
  their authored numbers, a missile is a *thrown object* with fall, bounce and fuse, an actor has
  four authored senses and the engine had two, and rope textures resolved nowhere in the game.
  Two engine-wide contracts came out of it and live in `Invariants.md`: a class input **extends**
  the base one rather than replacing it (`enable` was setting the class flag and losing
  `setActive`), and `postSpawn()`/class consequences must be virtual. **`meat` is the project's
  physics yardstick** (golden rule 4) and the phase deliberately did not move it: the crane reads
  `bodyDist=197.9/197.4/197.9/197.3 hingeAngle=+6.1°` before 36.0 and after 36.10, unchanged.
  What is still open is listed in `TODO.md` under `meat`, including eight defects the phase found
  and deliberately did not fix.
- `yae-engine/docs/Phase37_FixMainIssues.md` — the same method applied to the two level-independent
  sections of `TODO.md` (`new issues`, `general`): 22 items, 14 subphases. **Done** — 18 items closed
  (13, 14 by measurement; 4 handed to `Phase33_Graphics.md`; 17 by the user's decision), the remaining
  four carried into Phase 38. Most roots were of one shape, *authored data the engine parses and never
  reads*: a `type = 2` joint with all-zero limits is a **weld** in the original (ODE `LoStop == HiStop`)
  and a free hinge in ours — 495 of 538 joints, every car window; `params.hitboxes[].damage_k` was read by
  nobody, so a headshot was ×1.0; a `RigidBody`'s destruction `effect` (and its `sound_desc`) was only ever
  played by `Bomb`; god rays were the one per-level setting `unloadLevel()` did not reset. 37.13 is the
  one that reaches furthest: **a placement's forward is its `tm`'s local X, a character model's is its
  own Y**, and the quarter turn between them belongs to the engine — see `Invariants.md`.
- `yae-engine/docs/Phase38_ClosingPhase37.md` — Phase 37's tail: six items, six subphases. **Not
  started.** Two of them start with RE rather than a run (actor collision/impulse sensors; whether DS2
  spawns a `button` dynamic), one repeats a reverted fix by the approach already named (apply the EDF
  *after* `on_init`, as the original does — do not restore values on top of it), one is the audit that
  gates the rest: 11 files in the read-only `gameres/scripts` differ from the pristine tree in lines of
  code, and until they match, any measurement may be measuring them. **This is the current tracker for
  level-independent defects.**
- `yae-engine/docs/OriginalScriptDefects.md` — defects in the **original** game scripts, found by
  the Phase 38.0 audit and confirmed against two independent copies of the tree: an attack-selection
  pass that indexes with `nil`, `on_update` calling `on_init`, a type guard placed after the
  dereference it guards, `continue` and Lua-5.0 `for … in t do` (why the compat layer exists), and
  authored fields nobody reads. `gameres/` stays read-only **until the first stable build ships** —
  after that these become script fixes; until then they are compensated in the engine.
- `yae-engine/docs/phase38_gameres_edits/` — the local edits that had been made to the read-only
  `gameres/scripts` tree, saved as reversible diffs (`patch -R` reconstructs the original exactly).
  10 of the 13 are removed; the 3 that remain name the subphase that owns them.
  `bash scripts/compare_gameres_scripts.sh --list` is the live check — it compares the tree against
  `scripts/gameres_scripts_manifest.txt` (491 sha256 hashes, checked in because the reference tree
  lives outside this repo) and fails on any difference not on its ACCEPTED list.
- `yae-engine/docs/console/` — developer-console docs.
- Skills `yae-codeguide` (auto-invoked when editing C++/Lua) and `yae-review` encode conventions & anti-patterns.

## Golden rules

1. **C++ = engine primitives, Lua = game logic.** Thin bindings; let Lua prototypes decide behaviour.
2. **Never modify game resources** (`.ds2*`). Compensate in code (see `physics::kCrane*` for the meat-crane case).
3. **Preserve the deterministic frame order** (see Invariants.md) — reordering breaks game logic.
4. Physically-sensitive changes: verify on **m02/meat** (crane/joints/ropes) — see LevelTestMatrix.md.

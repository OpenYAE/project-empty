# YAE-dlls — repository guide

Reverse-engineering research project: a from-scratch C++20 re-implementation of the
DS2 engine (game "You Are Empty", 2006), plus the decompiled originals for reference.
**Game resources are treated as read-only** — never modify `.ds2*` asset files; reconstruct
missing behaviour in engine code instead.

This file is the short guide (since 2026-10-01, Phase 49). The long versions: **`yae-engine/docs/DevGuide.md`**
(layout, build, harness and gates in full — maintained), **`yae-engine/docs/Phases.md`** (every phase and
document: an index, then each one's digest — what used to fill this file), **`yae-engine/docs/Invariants.md`**
(the engine's contracts — read it first).

## Layout

- `yae-engine/` — the new engine (C++20, SDL3, OpenGL 4.5, Jolt, Lua 5.4). Main work happens here.
  `src/` is the engine library, `app/` the thin executable, `tests/` the startup self-tests,
  `shaders/` the GLSL (embedded at build time), `docs/` the documentation.
- `yae-game/gameres/` — original game assets (levels, models, scripts, textures). **Read-only.**
- `yae-game/documents_my games/YaE/` — what the original writes to *My Documents* (configs, key binds,
  every authored cvar default, savegames, logs). **Read-only reference** — `docs/UserFiles.md`.
- `yae-game/ds2base.cfg` — the original's directory table, read at startup: every `FS_PATH_*` comes from
  it; `$my_games$` resolves to `yae-game/my games/` (writable), never to `documents_my games/`.
- `yae-research-private/` — the **private** RE repository (own git, gitignored, never published): the
  decompiled originals (`decompiled/c-files/<dll>.dll.c`), unpacked shaders, Ghidra project, tools.
  `yae-research/` beside it is the **public** notes repository. **Citation convention:**
  `sv_game.dll.c:127553` is line 127553 of that export (frozen — a re-export would move every line),
  `FUN_0f8a7940` a function address in the original binary, `+0xa34` a field offset.
  **Not one build:** most binaries are 2006-11-11, but `sv_game.dll`, `ds2kernel.dll`,
  `ds2NavSystem.dll` and `you_are_empty.exe` are 2019 community rebuilds — behaviour found only there may
  never have existed in the 2006 game (`engine.play_comics` is the known example).
- `yae-materials/` — the community PBR catalog over the original textures (`PLAN.md`,
  `docs/GenerationPipeline.md`, the three-repo calibration plan `docs/MaterialCalibration.md` §0a). Its
  `export/` and `baked/` are derived (`npm run bake -- --all && npm run export-engine`); the engine
  auto-probes `<gameres>/../yae-materials/export/engine/catalog.yaemat` (`--no-materials-catalog` or
  `r_cvar mat_catalog 0` loads levels vanilla).
- `scripts/` — the gate scripts behind `build.sh --check`, gameres helpers (`gsf_dump.py`, …), the
  figure generators. History — the early phase plans, old audits and refactoring docs — is
  `yae-engine/docs/history/` (49.1).
- `project-empty/` — the umbrella README of the ecosystem (gitignored here).
- The SDK (`yae-sdk`) is a separate repository: canonical clone `~/PetProjects/yae-node-converter-claude`.

## Build & run

```bash
bash build.sh                       # `dev` preset (RelWithDebInfo, YAE_DEV, self-tests) → yae-engine/build/yae-engine
bash build.sh --check               # build + gates (warnings, self-tests, size budgets, gameres audit, console
                                    # reference, SDK conformance, clang-format on changed lines, doc links and
                                    # contents, level smoke) — before committing
bash build.sh --asan                # `asan` preset → build-asan; --self-test, a parse of med1/meat/gor, 60 frames of each
bash build.sh --release             # `release` preset (no YAE_DEV, no self-tests) → build-release
bash run_level.sh -map med1         # a level by stem or map dir; tees to yae-engine.log
./yae-engine/build/yae-engine --level yae-game/gameres/maps/map10/med1.ds2 --root yae-game/gameres [--edf <f.ds2edf>]
./yae-engine/build/yae-engine --model <path.ds2md> --root yae-game/gameres   # single-model viewer
./yae-engine/build/yae-engine --dump <asset> --root yae-game/gameres          # the parse as canonical JSON
./yae-engine/build/yae-engine --level … --frames 240                          # N frames, then a `perf` summary; exit 1 on [ERROR]
./yae-engine/build/yae-engine --level … --cvar r_normal_frame=1               # a render cvar for this run only
bash scripts/smoke_levels.sh [--shots] [level…]                               # smoke pass / picture gate (25 levels)
bash scripts/reference_scenes.sh [--record|--retail|--view albedo] [scene…]  # the 9 reference scenes (+ `calib` by name)
bash scripts/conformance.sh                                                   # our parsers vs the SDK's (~60 s)
bash scripts/campaign_stitches.sh [--chain]                                   # campaign stitches through their exit triggers
bash scripts/isolated_root.sh && export YAE_GAMERES=$PWD/yae-engine/build/iso/gameres   # runs on a copy with its own config/
bash scripts/no_change_gate.sh [--quick]                                      # Phase 49: one verdict "the picture did not change"
```

- **Isolated root — always, when the user may be playing.** Every engine run writes `config/settings.cfg`
  beside its asset root on exit and the gate scripts swap reference settings in and back; `YAE_GAMERES`
  points `build.sh`, `smoke_levels.sh`, `reference_scenes.sh`, `campaign_stitches.sh`,
  `save_roundtrips.sh`, `console_reference.sh` at the copy. Stop only your own engine processes, by PID —
  never `pkill` by name.
- **Game files come from the paks** (`resource/Vfs.h`): every pak but the sounds is mounted where its
  unpacked copy lies; the newer copy wins (a newer loose file is a mod). Loaders read through
  `vfs::read`/`list`, Lua through `vfs::luaDoFile` — never `std::ifstream`/`luaL_dofile` on a game path.
- **`build.sh --check` answers "is the tree still good"**; it fails on an own-code warning, a self-test
  failure, a file past its size budget (`scripts/size_budget.sh` — raise a ceiling on purpose, with a
  reason), an edit to the read-only `gameres/scripts`, a parser disagreeing with the SDK, an unformatted
  changed line (clang-format **19.1.7** from PyPI in a venv; `scripts/format_check.sh --fix`), a broken
  relative link or heading anchor in the markdown (`scripts/doc_links.sh`), a stale generated contents
  (`scripts/doc_toc.sh` — `Invariants.md`'s; a section without `Verified by` fails it too), or a level that
  no longer loads cleanly. Missing display / SDK / clang-format → that check says SKIP, loudly.
- **CI:** `.github/workflows/ci.yml` (Ubuntu build, self-tests, `release`, ASan) and `windows.yml` (MSYS2)
  are **manual** since 2026-10-01 (Actions minutes); every push runs only `lint.yml` (size budgets +
  format). The CI has no `gameres`: asset cases SKIP by name.
- **Presets** (`yae-engine/CMakePresets.json`): `dev`, `release`, `asan` (Jolt asserts logged as
  `[ERROR]`), `mingw` (Windows cross-build with llvm-mingw 20 + wine — `docs/WindowsBuild.md`).
  `scripts/tidy.sh` runs the small clang-tidy set — not a gate.
- **Smoke:** `smoke_levels.sh` loads the 25 golden levels for 120 frames; fails on `[ERROR]`, on a
  warning shape new against `scripts/smoke_baseline.txt` (a count fails only when it doubled and grew
  by 5+), and on a log saying `self-test summary: … FAILED` (the GL self-tests run only in windowed runs).
- **Picture gate:** `smoke_levels.sh --shots` — each level at frame 240, fixed camera, `--fixed-dt`,
  hidden window (`--offscreen WxH`, desk input dropped), 160-px tiles against local baselines
  (`--record-shots`, gitignored; last re-recorded in 48.10). A gate run pins `--materials-catalog
  yae-materials/export/engine/catalog.yaemat` and sets the `cvar.*` lines of `settings.cfg` aside; a
  `--fixed-dt` run is deterministic (Invariants.md) — a new wall-clock or `random_device` user in
  gameplay breaks the gate on `gor`/`metro` first. A refactor proves itself with noise 0.000.
- **No-change gate (49.0):** `scripts/no_change_gate.sh` — `--check`, smoke warning shapes equal to the
  baseline both ways, 25 shots + 9 scenes at worst tile 0.000, the `meat` crane line by line against
  `scripts/crane_baseline.txt`, the console reference; one line `no-change: OK` or the list. `--quick` —
  no scenes, no crane. Every Phase 49 subphase is handed in with it.
- **Self-tests** run at every windowed start and as a gate: `./yae-engine/build/yae-engine --self-test`
  (no window, no GL — GL cases SKIP; ~0.6 s; `--root <gameres>` for the asset cases). Run order is the
  explicit list in `tests/TestRegistry.cpp` — add a case there and in `SelfTestCases.h`.
- **Shaders** live in `yae-engine/shaders/` (`#include "x.glsl"`, one level); `--shader-dir
  yae-engine/shaders` + `shader reload` for live work. No GLSL in C++ (`grep -rl '^#version'
  yae-engine/src yae-engine/app` → nothing).
- **Graphics A/B:** the reference scenes are the A/B for every shader change (`--console "cmd; cmd"`,
  `--tag`, `--args`, `--no-post`, `--view <debug_view>`); `debug_view <albedo|normal|…|tangent>` shows one
  quantity untonemapped. Defaults (48.10): `linear` colour pipeline, `r_normal_frame`, `r_env_spec` on (the
  user's choice — remind them before changing it), relief gain 2, `r_retail_frame 0` (an A/B; the goal is a
  better picture, not retail's), `r_exposure 3`, `r_sky_brightness 1.5`, tone curve Reinhard. Curves
  (`r_tonemap 0…5`, `r_aces_*`, `r_tm_*`) and the colour grade (`lut`, `render.cfg` `lut_path`,
  `lut_level_dir`) — `docs/ToneMapAndLUT.md`. The colour contract — `Invariants.md`, "Colour space of
  authored data"; the material contract — `docs/MaterialContract.md`.
- **Perf:** `perf` in the console (`perf gpu`, `counters`, `vram`); `--frames N` prints it at exit. A doc
  that closes a perf item quotes the numbers before and after.
- **Menu/UI:** `YAE_SKIP_INTRO=1`; console `ui list|show|dump|trace`; `YAE_CONSOLE="cmd; wait 2; cmd"`
  scripts the console (menu included). Harness hooks and recipes: `docs/DevGuide.md`, `LevelTestMatrix.md`.

## Engine source map (`yae-engine/src/`)

`core` (Types/Logger/CoordConvert/PerfTimers) · `entity` (Entity + `EntityKind` — cast with `entityCast<T>`, a
class marks its kind with `YAE_ENTITY_KIND`; actors, doors, triggers, joints, ropes, FSM, I/O; the inventory
container, the hitscan trace, the explosion sink and the effect host; **no `game/` includes**) · `render`
(GL4 renderer, shaders, post-process, decals; the frame is a `RenderScene` filled by producers and drawn by
`GLRenderer::submit`) · `physics` (Jolt wrapper, ragdoll; **no `game/` or `render/` includes**) ·
`scripting` (Lua 5.4 bindings, the Lua 5.0 compatibility layer) · `ai` (combat loop, goals, perception) ·
`game` (the `GameRulesYAE` facade and its coordinators) · `assets` (`.ds2/.ds2md/.ds2cm/.ds2edf` parsers) ·
`audio` · `animation` · `navigation` · `ui` (also the comics player) · `scene` · `resource` (VFS) ·
`camera` (no `game/` includes: the cutscene director's hold on the player is callbacks, `game/CutsceneWiring.h`) ·
`input` · `video` (AVI cutscenes) · `effects` (PAPI particles, effect instances, flares; templates
parsed in `assets/EffectTemplate*`, instances owned by `game/EffectCoordinator`).

Input routing: `app/AppEventRouter` owns the SDL event chain (console → video → comics → cutscene →
ESC/pause → screenshot → frozen guard → debug → gameplay). **Order is the contract** — add a handler to
that list, do not bury a new `if` inside one. The frame is `app/FramePipeline`, one method per pass.

`GameRulesYAE` is the top-level facade; it delegates to coordinators (LevelLoader, WeaponCoordinator,
DebugCoordinator, PhysicsCoordinator, EffectCoordinator, GameLuaBinder, PlayerController, NPCSpawner).
Put new subsystems in a coordinator, not the facade. Console commands: registered in
`game/GameConsoleSetup.cpp` (a friend of the facade; order = the reference's order), families as
`game/<Family>Commands.{h,cpp}` — `docs/console/CONSOLE_ARCHITECTURE.md`. A saved knob (`r_cvar`) is one
row of `game/RenderCvars.cpp`. The player's Lua glue is `game/PlayerLuaBridge`, the carry between levels (and
in a save) `game/PlayerCarry`, the pre-destroy hook `game/EntityTeardown` — the facade's last member (49.6).

## How work is done here

- **A phase** gets its own document by the project's method: reconnaissance (numbers, not guesses) →
  items with their source → subphases with an acceptance number → "Сделано" with the numbers before and
  after; what was ruled out is recorded too. The user's decisions go into the phase's decisions table and
  `RetailSession.md`; contracts the work establishes go into `Invariants.md` with a `Verified by` line.
- **Measure, then change.** A picture change is shown with a same-config control (the gate's noise floor
  beats most effects); a physics change is checked on `meat`'s crane (golden rule 4).
- **Where we are (2026-10-01):** Phase 48 closed; **Phase 49 — audit and refactoring —
  `docs/Phase49_AuditRefactoring.md`** (49.0–49.9 done; every subphase is judged by "the picture did
  not change", `scripts/no_change_gate.sh`); then the mini-phase of the user's Phase 47 remarks
  (`docs/Phase47_Release1Readiness.md`, `Phase47_UserChecklist.md`), Phase 50 (cleaning for publication).
  The order and every phase's gates: `docs/Roadmap.md`; the index of all phases: `docs/Phases.md`.

## Docs (`yae-engine/docs/`)

| Document | What |
|---|---|
| `docs/Invariants.md` | the contracts: coordinates, frame order, ownership and init, state that outlives a level, … — 168 sections, each with `Verified by`, a generated contents at the top. **Read first.** |
| `docs/Phases.md` | every phase: index with status, then the digests (CLAUDE.md's former content, verbatim) |
| `docs/DevGuide.md` | layout, build, harness and gates — the long version of this file, maintained |
| `docs/Roadmap.md` | the order of the phases after 46 and their gates |
| `docs/LevelTestMatrix.md` | which level tests which subsystem (the table), then the recipes by level; videos and comics |
| `docs/TODO.md` | open items by level and `general` |
| `docs/history/` | what the engine *was*: plans 9–28, refactorings 25/29/31, old audits, old testing guides — not maintained (`history/README.md`) |
| `docs/RetailSession.md` | the user's retail checks, recordings and decisions |
| `docs/UserFiles.md`, `docs/SaveFormat.md` | the original's *My Documents* tree; the `.ds2gsf` format |
| `docs/MaterialSystem.md`, `docs/MaterialContract.md` | where materials are going; what every material field means, in numbers |
| `docs/ToneMapAndLUT.md` | the user guide to exposure, tone curves and the colour grade |
| `docs/OriginalScriptDefects.md`, `docs/phase38_gameres_edits/` | defects in the original scripts; the reverted local edits of `gameres/scripts` |
| `docs/WindowsBuild.md` | the Windows cross-build and its wine runs |
| `docs/RTGL1_Integration_Plan.md` | the experimental ray-tracing branch |
| `docs/console/` | `CONSOLE_ARCHITECTURE.md` (how to add a command); `CONSOLE_COMMANDS.md` — generated by `scripts/console_reference.sh` |

Skills `yae-codeguide` (auto-invoked when editing C++/Lua) and `yae-review` encode conventions and
anti-patterns. `bash scripts/stats.sh` prints the project's numbers.

## Golden rules

1. **C++ = engine primitives, Lua = game logic.** Thin bindings; let Lua prototypes decide behaviour.
2. **Never modify game resources** (`.ds2*`). Compensate in code (see `physics::kCrane*` for the meat-crane case).
   Horizon (user's decision 2026-09-18, `Phase46_EffectsParticles.md`): this holds for the pilot release; from
   the second version on, improvements may modify or replace resources — new formats, new versions of the
   old ones — as long as the untouched originals keep loading.
3. **Preserve the deterministic frame order** (see Invariants.md) — reordering breaks game logic.
4. Physically-sensitive changes: verify on **m02/meat** (crane/joints/ropes) — see LevelTestMatrix.md; the
   crane reads `bodyDist=197.3/197.4/197.9/197.9 hingeAngle=+6.1°` (`--frames 900`); the whole swing at
   `--fixed-dt`, line by line — `scripts/crane_baseline.txt` (`no_change_gate.sh --record-crane`).

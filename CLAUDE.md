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
- `yae-research-private/` — the **private** reverse-engineering repository (its own git,
  gitignored here; split out of this repo on 2026-09-18): the decompiled originals
  (`decompiled/c-files/<dll>.dll.c`, Ghidra and Hex-Rays exports), the unpacked shader
  programs, the Ghidra project, the symbol dumps and the analysis tools. Never published, never
  copied into this tree. `yae-research/` beside it is the **public** notes repository (the RE
  write-ups of Phases 3–8, no listings) that the docs portal ingests. **Citation convention** used throughout
  the engine's docs, sources and tests: `sv_game.dll.c:127553` is line 127553 of
  `yae-research-private/decompiled/c-files/sv_game.dll.c` (those exports are frozen — a re-export
  would move every line), `FUN_0f8a7940` is the function's address in the original binary and
  `+0xa34` a field offset — the last two are verifiable in any disassembler on the game's own
  files. **Not one build:** most binaries are 2006-11-11, but `sv_game.dll`, `ds2kernel.dll`,
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
  **Material calibration (2026-09-20):** `yae-materials/docs/MaterialCalibration.md` is the
  three-repo plan (MC-0…MC-7); its **§0a** is the handoff for the engine side — the materials
  side (CAL-00…CAL-04) is done: the synthetic calibration set (`yae-materials/calibration/`,
  `npm run calibration:make`; pack `calibration/pack/current.json`, stems `calib-<name>`; the
  same set bound to `med1`'s ward in `calibration/pack/level/current.json` —
  `reference_scenes.sh ward --tag calib --args "--materials-catalog …"`), `texelsPerMeter` and
  per-axis tiling measured into the records, a measured colour-space QA check, and packs that
  never carry a signed `normalScale`. What the engine owes before the Workbench `engine look`
  can start: `MaterialContract.md`, `--matball` + `matball.json`, `debug_view tangent`, the
  MC-2 sign table on `calib-bump-l` (hypothesis H1 — the V axis), and an answer to whether the
  `cubeman` template path bypasses the catalog's base colour (`plitkashahmatorez` on `ward`).
- `scripts/` — the gate scripts behind `build.sh --check` (smoke, picture, conformance, format,
  size budget, console reference), the gameres helpers (`gsf_dump.py`, `check_pak_sounds.py`, `effects_survey.sh`, …),
  the early engine phase plans (`Phase9_plan.md` … `Phase28_plan.md`) and engine audits
  (`Hardcoded_Constants.md`, `unimplemented_*.md`, `YAE_Architecture_Review.md` — a Phase-10
  snapshot, outdated). The RE notes that used to live here are in `yae-research/` (public), the tools in `yae-research-private/`.
- `project-empty/` — the umbrella README of the ecosystem (the draft of the future root
  repository; gitignored here).

## Build & run

```bash
bash build.sh                       # the `dev` preset (RelWithDebInfo, YAE_DEV, self-tests) → yae-engine/build/yae-engine
                                    # (a new .cpp is picked up by the next build — CONFIGURE_DEPENDS since 39.4.3;
                                    #  tests/ is listed explicitly in CMakeLists.txt)
bash build.sh --check               # build + gates: own-code warnings, self-tests, size budgets, gameres audit,
                                    # console reference up to date, SDK conformance, clang-format on changed
                                    # lines, level smoke pass.
                                    # ~30 s, stops at the first failure. Run it before committing.
bash build.sh --asan                # the `asan` preset (Debug, ASan+UBSan) → yae-engine/build-asan; then --self-test,
                                    # a parse of med1/meat/gor and, with a display, 60 offscreen frames of each (39.4.2)
bash build.sh --release             # the `release` preset (no YAE_DEV, no self-tests linked) → yae-engine/build-release
bash run_level.sh -map med1         # run a level by stem or map dir (map10, gor, vdnh1, meat, …); tees to yae-engine.log
./yae-engine/build/yae-engine --level yae-game/gameres/maps/map10/med1.ds2 --root yae-game/gameres [--edf <f.ds2edf>]
./yae-engine/build/yae-engine --model <path.ds2md> --root yae-game/gameres   # single-model viewer
./yae-engine/build/yae-engine --dump <asset> --root yae-game/gameres          # the parse as canonical JSON (Phase 39.1.5)
bash scripts/conformance.sh                                                   # our parsers vs the SDK's over the whole corpus (~60 s)
./yae-engine/build/yae-engine --level … --frames 240                          # 240 frames, then a `perf` summary of every stage and pass (Phase 39.0)
bash scripts/smoke_levels.sh --shots [level…]                                 # the picture gate: fixed cameras vs local baselines (--record-shots makes them)
bash scripts/reference_scenes.sh [--record|--view albedo|--budgets] [scene…]  # Phase 40's four reference scenes (ward/shop/yard/tunnel) at 1440p
bash scripts/campaign_stitches.sh [level…]                                    # 47.7: each campaign stitch through its authored exit trigger (kit carried, 0 [ERROR])
bash scripts/campaign_stitches.sh --chain                                     # 47.7: all 24 levels by name in one process (~6 min)
bash scripts/isolated_root.sh && export YAE_GAMERES=$PWD/yae-engine/build/iso/gameres   # 48.0: every run on a copy with its own config/
```

- `--level <path>` uses direct/CLI load (`loadLevelDirect`); campaign/transitions use `loadLevel` (by-name).
- **Runs while the user plays (Phase 48.0):** every engine run writes `config/settings.cfg` beside its
  asset root on exit, offscreen too, and the gate scripts swap the reference settings/`render.cfg` in
  and back — a race on the user's files. `bash scripts/isolated_root.sh [dir]` (default
  `yae-engine/build/iso`) builds the game as links with a `config/` of its own (`gameres/` is a tree of
  real directories with file links — a linked directory's `..` would lead back into `yae-game`), and
  `YAE_GAMERES=<dir>/gameres` points `build.sh` (`--check`, `--asan`), `smoke_levels.sh`,
  `reference_scenes.sh` (also `--root`), `console_reference.sh`, `campaign_stitches.sh` and
  `save_roundtrips.sh` at it. Stop only your own engine processes, by PID — never `pkill` by name.
- **The game's files come from the paks (Phase 47.9, 47.12):** every pak but the sounds is mounted where
  its unpacked copy lies — `levels/*.pak` at `levels/levels/`, `maps/*.pak` at `maps/<stem>/`, models,
  textures, materials, `rpl` and both script paks likewise (`resource/Vfs.h`) — so every path still reads
  as before; a file no pak holds (`vdnh1`, the films) is read from disk. **The newer copy wins, as in the
  original**: a loose file newer than its pak entry is read over it (that is a mod; the community patch's
  two HD textures are), an older one is not. Loaders read through `vfs::read`/`list`/`listFilesRecursive`,
  Lua files through `vfs::luaDoFile` (`resource/VfsLua.h`) — never `std::ifstream`/`luaL_dofile` on a game
  path. `--loose-tree` reads the unpacked copies instead (conformance does). Console `vfs [path|rescan]`
  names the archive a file comes from. `python3 scripts/paks_only_root.py <dir>` builds a Steam-like root
  (paks only, links) for `smoke_levels.sh --root` / `YAE_GAMERES=`. The unpacked copies are audited
  against the paks by `scripts/gameres_paks_audit.py` (check 4).
- Logs: `yae-engine.log` (run_level.sh tees), plus `yae-engine-test*.log`.
- `bash build.sh --check` is the one command that answers "is the tree still good": it fails on a
  warning in `src/`/`app/`/`tests/`, on a self-test failure, on a file past its size budget
  (`scripts/size_budget.sh` — raise a ceiling on purpose, never by accident), on an edit to the
  read-only `gameres/scripts` or to the unpacked levels/maps against their paks, on a parser reading a
  file differently from the SDK's
  (`scripts/conformance.sh`; a difference is either fixed or recorded in
  `scripts/conformance/accepted.txt` with its decision in `Invariants.md`), on a changed line that
  is not clang-formatted (`scripts/format_check.sh` — changed *lines* only, against
  `yae-engine/.clang-format`; `--fix` applies it), or on a level that stopped loading cleanly.
  Without a display the smoke pass is reported as skipped, not silently dropped; without the SDK
  tree next to the repo the conformance check says so and skips; without clang-format the format
  gate does the same.
- **CI (Phase 39.4.1):** `.github/workflows/ci.yml` runs the same gate on a clean Ubuntu runner —
  configure + build of the `dev` preset, warnings, `--self-test`, size budgets, format of the
  changed lines (with clang-format **19.1.7** from PyPI in a venv — the one version the gate is;
  apt's 18.x reads `AlignTrailingComments: Leave` differently and failed lines 19 had formatted), the `release` preset builds — and a second job runs `--self-test` under
  ASan+UBSan. `gameres` is never there (8.5 GB, outside git): the self-tests that parse it are
  **SKIP by name** (`assetCase` in `tests/TestRegistry.cpp`; the summary line groups the skips by
  reason), and the job summary lists what CI did *not* check. `.github/workflows/windows.yml` is
  the Windows build (MSYS2 UCRT64 GCC, build + `--self-test`), a separate status on purpose.
- **Presets** (`yae-engine/CMakePresets.json`): `dev` = what `build.sh` builds (`build/`),
  `release` = `YAE_DEV=OFF`, `YAE_BUILD_TESTS=OFF` (`build-release/`; `--self-test` there says so
  and exits 2), `asan` = RelWithDebInfo + `YAE_SANITIZE=address,undefined` + Jolt's `USE_ASSERTS`
  (`build-asan/`; a Jolt assert is logged as `[ERROR]` and the run continues — 41.3; the one
  accepted assert, equal hinge limits, is logged once as INFO; `YAE_JOLT_ASSERT_BT=1` prints the
  call stack of the first three, `addr2line -f -C -e build-asan/yae-engine <+off>` names it — 46.9b).
  `YAE_FETCH_DEPS=OFF` is a real branch now: `find_package` for SDL3, Jolt, glm and Lua 5.4, and
  it fails by package name when one is missing. `mingw` cross-builds for Windows with llvm-mingw
  from `~/opt` (no root) and wine runs the result — **`yae-engine/docs/WindowsBuild.md`** is the
  instruction: which llvm-mingw release (LLVM 20; the 2026 ones break Jolt), the two wine runs
  (`--root 'Z:\nonexistent'` is what the runner sees), what counts as passed, and the classes of
  defect this build finds that GCC on Linux does not. `scripts/tidy.sh [files]` runs clang-tidy with the
  small `bugprone-*`/`performance-*` set in `yae-engine/.clang-tidy` — not a gate.
- **Menu/UI work:** `YAE_SKIP_INTRO=1` skips the 24 s logo so the main menu is up in ~4 s, and the
  `ui` console command drives it: `ui list` (21 screens), `ui show <widget>` opens one without
  clicking to it, `ui dump <widget>` prints the tree with config vs computed rects and `NO-MATERIAL`
  flags, `ui trace on` logs hit-tests. `YAE_CONSOLE` works in the menu too (no level needed).
  Reference shots of the original are in `yae-engine/tests/referenses-menu/`, ours in `ours/`.
- **Smoke test:** `bash scripts/smoke_levels.sh` (~35 s, needs a display) loads all 18 golden levels
  for 120 frames each and fails on any `[ERROR]` or on warnings that are new against
  `scripts/smoke_baseline.txt` (folded to message shape + count, since a lot of the originals'
  warnings are legitimate and never reach zero). A count that grew is only a failure when it both
  more than doubled and grew by 5+ — some warnings repeat on a timer, so ±1 between runs is noise.
  `--record` rewrites the baseline, `--frames N` runs longer, and naming levels (`… med1 meat`)
  checks a subset. The engine flag behind it is `--frames N`: run the real loop N times, then quit
  with 0, or 1 if anything logged `[ERROR]`. A level whose log says `self-test summary: … FAILED` fails
  too (48.0): the GL self-tests run only in windowed runs — `--self-test` SKIPs them — and `Grey card`
  had failed unseen for a day.
- **Shaders (Phase 39.2.3)** live in `yae-engine/shaders/` (`*.vert`, `*.frag`, `*.glsl` include
  blocks) and are embedded at build time (`cmake/EmbedShaders.cmake` → `build/generated/`); a new
  file is picked up by the next build, no reconfigure. `#include "x.glsl"` is resolved one level deep,
  and a `Shader::createFromFiles(vert, frag, {"SKINNED"})` define list selects a variant. To work on
  one: `--shader-dir yae-engine/shaders`, edit, `shader reload` in the console (a file that no longer
  compiles keeps its old program). A smoke run (`--frames`) compiles every file first, so a broken
  shader is an `[ERROR]` even on a level that never reaches its pass. No GLSL in C++: the check is
  `grep -rl '^#version' yae-engine/src yae-engine/app` → nothing.
- **Graphics work (Phase 40.0):** the four reference scenes (`scripts/reference_scenes.sh`,
  `tests/referenses-scenes/README.md` — cameras, reference settings, the original's frames still to
  capture) are the A/B for every shader change; `debug_view <albedo|normal|roughness|metallic|direct|
  indirect|ao|lightmap>` in the console shows one quantity untonemapped (`--view <name>` shoots every
  scene in it; not a saved setting). Budgets per scene are in `Phase40_GraphicsRealism.md`, 40.0.3.
  `--retail` shoots the `slot-*` scenes (a retail quicksave loaded, 1920×1080 — 47.1, D9) and
  prints the scale and FOV against the retail frame. `--console "cmd; cmd"` runs console commands into every shot, `--tag name` names the output,
  `--no-post` drops the composite, `--args "--flag"` passes engine flags — an A/B is two such runs.
  **Colour pipeline (40.1):** `r_cvar r_color_pipeline 1` is the linear profile (live, no reload;
  `legacy` = 0 stays the default), `r_light_falloff 1` the physical inverse-square falloff with the
  level's coefficient (`lights calibrate [target]` prints it; `yae-overlay/authored/levels/<stem>/lights.yae`
  stores it, the exposure and per-lamp overrides), `r_auto_exposure` (off) a histogram exposure,
  `r_shadow_alpha` (on) alpha-tested shadow casters (40.2.2: a grate shadows its texels; `perf counters`
  prints how many casters bound a texture for it).
  The contract — pure γ 2.2 decode in the shader, multipliers to the γ, lerps in display space, one
  encode — is `Invariants.md`, "Colour space of authored data"; the identity criterion is
  `reference_scenes.sh --no-post --console "use_lights off"` legacy vs linear at 0.000.
- **Perf (Phase 39.0):** `perf` in the console prints median/p95/max of every stage of `gameFrame()`
  and every pass of the frame over the last 240 frames (`perf gpu` the GPU side, `perf counters`
  draws/binds/uniform calls, `perf vram` the engine's own byte ledger); `--frames N` prints the same
  block at exit and the smoke pass keeps it as `build/smoke/<level>.perf`. Measure before and after;
  the doc that closes a perf item quotes both numbers. On `med1` (offscreen 3440×1440) the frame is
  now ~3.7 ms: ~7 700 shadow draws after the per-light caster cull (39.3.4; it was 156 000) and
  3 500 world draws at 0.7 ms — `perf counters` prints "shadow casters N of M".
- **Picture gate (Phase 39.0.4):** `bash scripts/smoke_levels.sh --shots` shoots each golden level at
  frame 240 from a fixed camera (`--fixed-dt`, so two runs are pixel-identical) in a hidden window
  of the baseline's size (`--offscreen WxH` — no fullscreen, no focus, so the desk being in use, the
  cursor's display and stray keystrokes cannot reach it) and compares 160-px tiles with
  `tests/referenses-<level>/ours/baseline.png`. A run that logs an `[ERROR]` or writes no shot is a
  failure, never a comparison against the previous run's file. Baselines are local (`--record-shots`,
  gitignored — they depend on this machine's resolution and gamma); a rendering refactor that must
  not change the picture proves it with noise 0.000 here. The baselines were last re-recorded in
  42.0 (all 18, after the 2026-09-13 renderer commits `4363d82`/`cdddbfd`; before that in 41.6 for the
  authored fog and `lastzlo` in 41.12; since then single levels with a reason — `grsvt` 42.4,
  `lastzlo` 42.2/42.7, `meat` 42.7). **Since 42.0 a gate run is pinned:** every engine invocation
  gets `--materials-catalog yae-materials/export/engine/catalog.yaemat` (the Workbench pointer
  `yae-materials/.yae/workbench/exports/current.json` otherwise overrides it silently — 1119 matched
  meshes on `kolhoz` instead of 9014, and 14 levels "failed"), and the `cvar.*` lines of
  `config/settings.cfg` are set aside for the run so the engine shoots on its code defaults
  (`r_lm_relief_gain=16` had leaked in). The script restores `config/settings.cfg`
  when it exits: an `r_cvar` set through `YAE_CONSOLE` is a saved setting and would otherwise leak
  into every later run. `--fixed-dt` also makes the run **deterministic** (Invariants.md, "A
  `--fixed-dt` run is the same run every time"): sound playback state on the game clock (40.1.5),
  gameplay chance from `core/Random.h` with a fixed seed, and the bundled Lua's string hash pinned
  (40.2.2 — as a raw `-D` option: CMake drops a function-style compile definition silently, and
  the pin was missing until the `wall` follow-up caught `gor` flipping again; self-test `luaHashSeed`; Lua's `math.random` seeded and `engine.get_system_time()` on game time under
  `rng::harness()`, self-test `luaHarnessRandom`) — each was a gate flipping between two pictures. A new wall-clock or `random_device` user
  in gameplay breaks the gate on `gor`/`metro` first.
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

`core` (Types/Logger/InterfaceServer/CoordConvert) · `entity` (Entity + `EntityKind`, actors, doors, triggers, joints, ropes, FSM, I/O; also the inventory container, the hitscan trace and the explosion sink — the primitives the game layer builds on)
· `render` (GL4 renderer, shaders, post-process, decals, the physics debug renderer; the frame is a `RenderScene` filled by producers and drawn by `GLRenderer::submit` — Phase 39.2.2) · `physics` (Jolt wrapper, ragdoll; **no `game/` or `render/` includes** — Phase 39.5.1, see `Invariants.md`)
· `scripting` (Lua 5.4 bindings) · `ai` (combat loop, goals, perception) · `game` (GameRulesYAE facade +
coordinators, `PhysicsCoordinator` among them since 39.5.1) · `assets` (`.ds2/.ds2md/.ds2cm/.ds2edf` parsers) · `audio` · `animation` · `navigation`
· `ui` (also the comics player) · `scene` · `resource` · `camera` · `input` · `platform`
· `video` (AVI cutscenes: decoder backend + player + preset resolution)
· `effects` (Phase 46: the PAPI simulation `Papi`, `EffectInstance`, the particle draw list `ParticleManager` and
`ParticleRenderer`, the `object_flare` system `FlareSystem` (46.8); the templates are parsed in `assets/EffectTemplate*`,
the flare tables in `assets/FlareTable*`, the instances live in `game/EffectCoordinator`).

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
- `yae-engine/docs/MaterialContract.md` — **the material contract** (Phase 48.1, version 0.1; 1.0 at
  48.11): what every field of a material means, in numbers — twelve rules (slots; base colour a display
  value under pure γ 2.2, data maps linear; rows never flipped, row 0 = `v = 0`, T along +U / B along +V,
  the `opengl` green's axis *pending* 48.5 — H1; `normalScale` ≥ 0, 1.0 = authored; α = r², F0 =
  mix(0.04, albedo, metallic); AO indirect only; lightmap [0, 0.5] ×2; the relief imitation with its
  gain/clamp/L; lamps × 0.25; the composite per profile; 64 units/m and `texelsPerMeter`; the three shared
  GLSL files by sha256), each with `file:line` and the self-test or `matball` measurement that holds it;
  the glTF 2.0 / UE / Unity / Blender table and how their materials come in without editing pixels;
  appendix A — `.yaemat` dialects 1 and 2 as `MaterialCatalog.h` reads them; appendix B — `matball.json`.
  Workbench, the review sheet and the SDK viewers mirror the engine by it. Found writing it: triangle
  strips get no tangent frame (4 219 lit surfaces with a catalog normal map sit on the fallback world
  X/Z — fixed in 48.6), and a one-channel base colour samples red.
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
  `scripts/gameres_scripts_manifest.txt` (497 sha256 hashes; since 45.19b the reference is the two
  script `.pak`s themselves — the shipped scripts — unpacked in place) and fails on any difference
  not on its ACCEPTED list.
- `yae-engine/docs/Phase39_EngineHardening.md` — the engine-hardening plan (observability, lifetime,
  the frame out of `main`, GPU-resident frame data, CI/sanitizers, layers, threads, docs). Renamed from
  38 when the Phase 37 tail took that number. **39.1 is done** (2026-09-11): pending I/O holds its
  activator by id, `BinaryReader` bounds checks cannot overflow, a save slot is written as a staged
  set (temp + rename, all three files or none), the second pass over local statics (`stuck_recovery`
  is the saved cvar `ai_stuck_recovery`), and **parser conformance with the SDK** —
  `scripts/conformance.sh` runs our parsers and the SDK's over every asset (1 947 files), diffs the
  canonical dumps, and is the fifth gate of `build.sh --check`. Its first run found three engine bugs
  (nav-portal links, EDF last-definition-wins, keyed `.rds` parts), two SDK bugs and a `gameres`
  tree defect (~20 case-variant EDF pairs from unpacked base + patch paks); the decisions are in
  `Invariants.md`, "Parser conformance with the SDK". **39.0, 39.2 and 39.3 are done** too: `perf`
  timers/counters/VRAM ledger and the offscreen picture gate; the frame out of `main`
  (`app/FramePipeline`), the `RenderScene` + `SceneResources` registry, shaders as files; the
  per-frame UBO, the material SSBO, bindless textures and the per-light shadow-caster cull — on
  `med1` the world pass went 1.96 → 0.71 ms CPU, the shadow pass 11.7 → 1.0 ms (156 000 → 7 700
  draws) and the frame 22 → 3.7 ms, with the picture unchanged on all 15 golden levels.
  **39.4–39.7 are done too** (2026-09-11): CI + presets + ASan + format gate (39.4), the layer
  inversions and `Entity::kind()` (39.5), buffered Jolt contacts with the thread pool and async
  textures *declined by measurement* (39.6), `Invariants.md` with a `Verified by` line per section,
  phase docs stamped as history, `scripts/stats.sh`, the generated console reference (39.7).
  **Phase 39 is closed**; what it left open is on the runner (first push) and in 39.4.1 (two Windows
  path failures with assets).
- `yae-engine/docs/Phase40_GraphicsRealism.md` — the second graphics plan (linear light, material
  data, environment, baked GI), renamed from 39 with the above. Depends on Phase 39's 39.0/39.2/39.3.
  **40.0 and 40.1 are done** (2026-09-12): the four reference scenes, `debug_view`, per-scene
  budgets; then the linear colour pipeline as a live profile beside `legacy` — pure-power decode in
  the shader (the identity `diffuse × lightmap × 2` holds to 0.000 on all four scenes with lights and
  composite off), the composite in linear (AO on the indirect share, exposure, bloom, tone map, one
  OETF), physical falloff with a per-level coefficient and exposure both anchored to the legacy
  picture (`lights calibrate`, `lights.yae`), and three GL/CPU self-tests. `legacy` remains the
  default until the originals are eyeballed. **40.2 is done too**: the render queue draws in four
  layers (opaque, masked, opaque decal, blended by `sort_value` then far-to-near), alpha-tested
  shadow casters (`r_shadow_alpha`), horizon-based AO with bilateral blur and upsample on the
  geometric G-buffer normal, the catalog's lightmap-as-AO gain retired. The pre-release part of
  Phase 40 is complete; 40.3+ waits for the playable build.
- `yae-engine/docs/Phase41_FixMed1KolhozGor.md` — the per-level method again, for the leftovers of
  `med1`/`kolhoz` and the first pass over `gor` (`gor_part_2`) and `gorkonec`: ten items, eleven
  subphases (twelve with 41.12). **Phase 41 is closed — 41.0–41.12 done** (2026-09-12/13). 41.9 (the
  cabinet bottle standing through its shelf) closed on a root outside its plan: the authored pose is
  impossible (a 23.2-unit box in an 18.1-unit compartment) and **Jolt resolves it in its position
  phase** — no velocity, mirror-image manifolds from shelf and floor, zero torque — where ODE 0.5
  resolves it as a real velocity with per-triangle contacts, so the original's bottle tips over.
  `physics/JammedPlacement.h` states the outcome: a dynamic *pickup* born jammed (a two-probe test
  with back faces — `medkit06`'s centre sits inside the shelf board) is laid on its side before its
  first step where it fits; props are left as authored. 5 pickups across the campaign (all in
  `med1`/`med2` wall cabinets), 27 jammed props untouched, picture gate 17/17 unchanged —
  `Invariants.md`, "A pickup born where it does not fit lies down"; self-test `Tall item topples`;
  `PhysicsWorld::overlapsAt`/`boundsAt`; `contacts <e> all` now really prints persisted contacts
  of the named bodies. 41.10 closed by measurement on `Door_Aptechka00` (`io` + `trace`: kinematic
  box swings with the leaf, the ray crosses the opening to the medkit). Note for harness runs:
  `--fixed-dt` takes a value (`--fixed-dt 0.0166667`); `--fixed-dt --offscreen …` silently runs
  on real time and eats the next flag. Before that: `gor_part_2` and `gorkonec` are in the
  smoke and picture gate (17 levels), `Lightmaps: N/M loaded` with pages missing is a WARN naming
  them, every item has a verified recipe in its subphase, the `meat` crane numbers are recorded;
  `FileSystem::resolvePath()` matches a name case-insensitively when the exact spelling names
  nothing (one cached listing per directory, one log line per name — `Invariants.md`, "An asset
  name is matched without regard to case"; self-test `CaseInsensitivePath`), and `gorkonec` reads
  `Lightmaps: 2/2 loaded` — across the campaign those two pages were the only names that needed
  it; the viewmodel is drawn into the front depth band (`glDepthRange(0, 0.01)`,
  `GLRenderer::kViewmodelDepthRange`) instead of after a depth clear, so the live depth is world +
  weapon, the god-ray mask sees the gun as an occluder and 32.8.1's depth snapshot (a full-res
  blit per frame) is gone — `Invariants.md`, "The viewmodel is in front by depth range";
  GL self-test `God-ray viewmodel mask`; the ZIL crash is closed by the original's own rule, read
  in the decompiled ODE 0.5: **a body entering the physics world brings in the dormant bodies its
  joints tie it to** (`PhysicsWorld::addBodyToWorld`; a leaving body parks its constraints; hidden
  and `shapes_enabled = false` bodies are kept out — `Invariants.md`, "A joint brings its dormant
  end into the world"), plus two campaign-wide motor roots — the authored `x_F`/`x_V` hinge motor
  nobody read and `set_velocity` on a hinge being **degrees per second** — self-test `Joint to
  dormant body`, `props` prints `motion:`/`shape:`/`com`, `joints` prints `motor`, and
  `physics_debug` is a console command. The truck now drives instead of crashing but stops short
  of the scene's stop trigger — an open, measured item under `gorkonec` in `TODO.md`, planned as
  41.12 (runs before 41.11). 41.4 answered what a disabled `RigidBody` *is* by reading the ODE 0.5
  in `ds2physics.dll`: **frozen and solid** — `Enable(false)` is `dBodyDisable` and nothing else,
  only `Hide` drops the geoms, and `AddForce`/`SetLinearVelocity`/the island walk all re-enable it.
  A dormant body is now a kinematic body in the world, woken by `enable`, a joint, a live body's
  or a moving lift's contact, a character's touch, or a push (`PhysicsWorld::setBodyDormant`/
  `wakeDormant`; `RigidBodyEntity::syncBodyToState()` is the one function behind
  `show`/`hide`/`enable`/`disable`/`*_shapes`; hidden bodies stay out); measured across the
  campaign's load path: 174 such props, 18 only ever shown, 57 never enabled by anything — all
  walk-through until now. A joint to a dormant end is built (it used to be skipped as
  "non-dynamic", which is why the ZIL lost its wheels' joints), the blast recognises a dormant body
  by its mark, `props` prints `kinem dormant` — `Invariants.md`, "A disabled body is solid";
  self-test `Dormant body is solid`. 41.6 (the zeppelin that "disappears and returns") closed on a
  root outside its plan: **the authored fog had never been applied on any level since Phase 24.1**
  — `parseEntities()` moves its definitions out and `extractFogSettings()` read the emptied member;
  the airship popped in and out at `camera_zfar = 15000` as a hard silhouette where the authors
  end the fog at exactly 15 000 to hide that cut. Both plan hypotheses were ruled out by
  measurement (no model culling exists in the main pass; the clip joint is one held-pose frame),
  the fix is one call site, the picture changed on 16 of 17 gate levels and all four reference
  scenes (baselines re-recorded, ≤ 2.2/255 mean; the 40.1.2 legacy/linear identity holds with fog
  at 0.000), and the four passes that still ignore fog (decal, water, particle, rope) are handed to
  40.6.4 with numbers — `Invariants.md`, "The authored fog is applied, and it ends where the camera
  does"; self-test `EDF fog reaches the renderer`; console `screenshot [file]` (a frame series
  from one run with `wait`). The user then checked the retail game: the *shipped* airship is
  `DEREJOBA` on `gor_part_2` (not the karma dump's), it hovers and **leaves by its arrival clip
  played at `speed = -0.6`** — and our `anim_play` dropped the sign, so it jumped away and arrived
  again; a negative speed now plays a clip backwards from its end and `speed = 0` keeps the speed
  it had (8 authored reversed plays, 20 EDFs with `0`) — `Invariants.md`, "A negative animation
  speed plays the clip backwards"; self-test `Animation plays backwards`; `fire_io <entity>
  <output>` fires an authored output by name (`fire_io TRG_Derej on_enter`), `YAE_DUMP_FRAMES=1
  --dump` prints a clip's keys. 41.5 (the `gor_part_2` doors): only the physics pair `_02` was
  stuck, and by its own frame — the hinge is authored inside the door post, and a leaf that
  collides with the level jams on a hard hinge where the original's `BhvDoor::DontCollideWithStatic`
  drops the world bit; a `fixing = false` leaf is now on `PhysLayers::DOOR_LEAF` (no pair with
  STATIC) — `Invariants.md`, "A door leaf does not collide with the level"; self-test `Door leaf
  ignores level`; `io <door>` prints `door:`/`hinge:`/`body:`, the console `use` presses both halves
  of the key. The other six doors are as authored (`_01` locked *and welded to each other*, `_05`
  unlocked by its trigger). 41.7 (the `med1` dog with no arrival sound) closed on our own rule: 34.6.2
  had let a name in `react_objects` beat a side token in `skip_objects` so that `YAKOR_KONEC01`
  would `destroy` the dog on arrival, but the original's filter (`sv_game.dll` `FUN_0f8a7940`)
  tests the actor's side *after* the name and rejects on the skip regardless — that zone fires for
  nobody, the dog reaches its anchor, goes `idle` and growls (`Dog_idle2/3`; `Dog_idle1` has no
  file — `OriginalScriptDefects.md` C4). One `Trigger` and five unread `ai_anchor`s in the campaign
  change; `Invariants.md`, "A side token in `skip_objects` wins"; self-test `Dog guard errand`.
  Found and left in `TODO.md`: NPC run/walk sounds start twice (C++ `updateActorStateSounds` and
  Lua `visualize_state`). 41.8 (`legs_fsm` re-entered 18×/s) was our binding, not the original's
  design: `get_fsm_state` returned a fresh table where `add_fsm_state`/`get_cur_fsm_state` return
  the name, so the authored `if(cur_legs_state ~= fsm_move_state)` never held (all three hand out
  the name now, unknown → `nil`). Reading the original's FSM on the way (`sv_game.dll`
  `FUN_0f829500`/`FUN_0f829600`) replaced two invented rules in `FSM.h` with its contract: **no
  same-state guard, and a non-forced `change_fsm_state` waits for the state's `is_finished`**
  (pending, applied after the update tick that ends the state; `force` defaults to `true`;
  `is_finished` is called as a method) — `Invariants.md`, "FSM self-transitions"; self-tests `FSM
  loop restart` (rewritten), `FSM handle identity`; a torso visual with the overlay off is dropped
  while the legs own the base track instead of being taken back by the next tick's re-assert.
  Consequence recorded for a retail check in `TODO.md`: every actor now enters `empty` at `on_init`
  as the script says (idle frame 1 + its idle sound), so `med1`'s start has two hidden actors in
  earshot; `krovli`'s picture baseline re-recorded (a shifted RNG draw picked another weapon
  idle clip), `smoke_baseline.txt` refreshed for `dog_idle1`. 41.12 drove the ZIL scene to its end on three roots, none of them the
  plan's hypotheses, found with two new console probes — `trace x,y,z [dir] [len]` (a ray: what is
  there, whose) and `contacts <a[,b]> [all]` (a body's contacts as they happen): the truck sat its
  tail on the escort motorcyclist, because **an actor's inner body is infinitely massive to every
  prop** while the original gives it its authored mass (now a contact with a heavier dynamic body is
  a sensor contact and the character's own recovery is the shove); the gate-breaking trigger saw the
  truck 140 units late, because `TriggerZone` added the entity's world-aligned box to the zone's
  *local* axes — wrong by a quarter turn for a zone authored across the road (now the OBB is
  projected onto the trigger's axes); and the curb was cleared only on rounding luck, because
  `MaterialScriptLoader` had **invented 0.06–0.65/s of damping for every dynamic prop** since Phase
  24 while ODE 0.5 has none (now zero; doors/debris/`.phs` props keep their explicit values) —
  `Invariants.md`, "A heavier body shoves an actor", "A trigger meets an entity's box along its own
  axes", "A body has no damping of its own"; self-tests `Heavy body shoves actor`, `Trigger rotated
  box sees length`; `lastzlo`'s baseline re-recorded (its start lift is a passive dynamic body the
  damping had been holding up — `TODO.md`). Three roots
  were already named by the reconnaissance —
  `gorkonec`'s lightmaps never loaded (`gorKonec_lm_*` in the `.ds2` vs `gorkonec_lm_*.tga` on
  disk; the original ran on a case-insensitive FS — closed in 41.1), god rays
  passed through the viewmodel because the scene depth was captured before the FP pass (closed in
  41.2), and the ZIL
  scene crash reproduced with one console command (`fire_io TRG_zil_anim execute`, died in Jolt's
  broadphase; also by spawning inside `TRG_zil_anim` — closed in 41.3). 41.0 added two that
  change items: **the
  zeppelin is not on the shipped `gor` at all** (only in the `gor_karma`/`gor_cars_lastscene`
  editor dumps no EDF includes — item 7 needs `--edf gor_karma.ds2edf` and a decision), and
  **`props` does not list doors** (41.5/41.10 start with a `door:` diagnostic).
- `yae-engine/docs/Phase42_FixMeatWallGrsvt.md` — the per-level method for the leftovers of `meat`
  (Phase 36's eight deliberately unfixed defects) and the first pass over `wall` and `grsvt`
  (gorsovet): 14 items, 13 subphases. **Phase 42 is closed — 42.0–42.12 done** (2026-09-13/14),
  all 14 items marked with their subphase and root (three by measurement: meat's first-belt
  damage, wall's back-shot, wall's final door). **42.0 done** (2026-09-13): `grsvt` is the 18th level of the
  smoke and picture gate (camera on the gallery looking at `RIGID_lustra`'s twelve mirrored
  plafons), the crane numbers are recorded, the three recipes that needed a spawn have one (the
  `wall` final door, `TRIGGER_backshot`, the `meat_part2` hatch — which turns out to be the
  **`meat_part2 → wall`** exit: a manhole over a shaft with `THE_END` inside it). 42.0 also found the
  picture gate red on 14 of the 17 older levels before any Phase 42 change — the renderer commits
  of 2026-09-13 (`4363d82`, `cdddbfd`) after the 03:55 baselines plus the Workbench catalog
  pointer (`yae-materials/.yae/workbench/exports/current.json` overrides `export/engine/`), measured
  in the doc; by the user's decision the gate is now pinned to `export/engine` and default cvars, and
  all 18 baselines were re-recorded. **42.1 done** (2026-09-14): `CounterEntity` reads
  `input_data.value` from the authored parameter table (`IOParams`; slot defaults as
  `sv_object_counter` registers them; `check()` fires only `on_value_equal` at the reference) —
  the Beria door opens, `meat`'s `karloson_02` and `theatre`'s `Counter_Doors` chains fire; self-test
  `Counter reads param table`. Found on the way and left in `TODO.md` `general`: the authored
  `damage` command (27 in the campaign, `{damage_type, hit, kill}`) is parsed the same wrong way and
  always deals 100 — RE of `sv_game.dll`'s handler first. **42.2 done** (2026-09-14): `Barrier`/
  `BarrierAI` are `BarrierEntity` with a static body of the authored size on `PhysLayers::BARRIER`/
  `AI_BARRIER` (characters only; the player filters `AI_BARRIER` out; gameplay rays skip both,
  `trace` sees them) — `grsvt`'s `BARRIER_08` stops the player at x 31.4; self-test `Barrier body
  from size`; new console `hold <cmd> [s]` (a held key for harness runs); `lastzlo`'s baseline
  re-recorded (its friction-held start lift settles differently with more bodies in the world).
  **42.3 done** (2026-09-14): `remove_actor_item_by_classname` takes items out of the actor's Lua
  `__inventory` through `WeaponCoordinator::removeInventoryItemsByClass` (entities destroyed, a held
  weapon holstered and `select_weapon(BEST)` rerun, ammo recounted) — room 101 empties the hands;
  self-test `Remove item by classname`. **42.4 done** (2026-09-14): a `tm` with det < 0 (grsvt's 24
  plafons, the campaign's only ones) is split B = R·M in `Entity::adoptAuthoredTransform` — the body
  gets `properBasis()` (det +1, vertical kept), the render instance the body's pose times the
  mirror — the plafons stand on the chandelier rings; self-test `Mirrored placement keeps pose`,
  `grsvt` baseline re-recorded. **42.5 done** (2026-09-14): a door turns about its placement's own
  Z (`DoorEntity::hingeAxisZUp()` — leaf, kinematic body and hinge constraint alike; the original's
  `AddHinge` axis is the `tm`'s third column) — meat's manhole lid lifts instead of spinning in the
  floor plane, poh's `Kachel` swings, andr's levers tilt; and a ladder climbs along its most
  vertical axis (meat's `Ladder_01` is authored along local −Y) — the `meat_part2 → wall` exit is
  walkable with `use` + `hold`; self-test `Door swings about its axis`. Found: `lastzlo`'s
  picture flakes 1 run in 5 (the friction-held lift) — in `TODO.md`. **42.6 done** (2026-09-14): a
  hidden or `shapes_enabled = false` RigidBody is a ghost (`PhysLayers::GHOST` — no pairs, no rays,
  no pushes; frozen; woken only by a joint), as `ODE::Body::Hide` = `dBodyDisable` + `dGeomDisable`
  — meat's eight hidden wheel knockers ride the wagon's welds into the seven knock triggers (48
  knocks a ride); self-test `Hidden body rides joint`. **42.7 done** (2026-09-14): a `Conveyor` is
  a static box of its authored `size` whose surface moves (`PhysicsWorld::setSurfaceMotion` →
  `ContactSettings::mRelativeLinearSurfaceVelocity`, ODE's `dContactMotion1`; a character reads it
  as its ground's velocity, projected onto the ground's tangent plane) — meat's m03 chain is ridden
  on the belt tops at exactly 150/…/333 u/s to the authored lava trough, `M06_01` at 195.7/s for 24 s,
  a canister rides belt 01 at 148 u/s; the character keeps the carry of its last ground in the air
  (`airCarryVelocity_`), which also moved `lastzlo`'s friction-held lift (baseline re-recorded, as
  was `meat`'s — its gate camera stands on `CONVEYOR_M06_01`); self-tests `Conveyor carries body`
  / `Conveyor carries character`. **42.8 done** (2026-09-14): the plan's hypothesis was refuted
  by measurement — an actor rides a published carrier since 35.6 (`io <actor>` now prints its
  ground body and carry, `io <lift>` the travel it publishes); meat's fireman was never *on* the
  lift: `snapToNavGrid` pulled him 123 units down to the shaft's grid cell under the platform (and
  its floor ray had never run at level load — gated on a body built one lifecycle step later; 191
  actors started in the air). An actor now spawns on the floor under its placement, a kinematic
  platform included, and a cell 30+ below that floor is refused — `Invariants.md`, "An actor
  spawns on the floor under its placement"; self-test `Actor spawns on platform`; the authored
  scene (sparks trigger → lift down scoops him off `BARRIER_AI_M12_01` → up to the
  `blockmovement_off` trigger) runs end to end. **42.9 done** (2026-09-14): the FSM cadence
  question answers itself in the scripts — `set_fsm_update_time` = the clip's length, honoured
  since 37.8b (the Karlson's take-off `jump5_vzlet` runs its full 1567 ms) — and the jerk was
  after the clip: `moveTo` under `block_movement` dropped the goal's order, so the unblocked
  Karlson stood in `alert1_p1` for 200 ms until the chase goal's next 0.5 s repath (the original's
  `"chase"` re-plans every 1–6 s, RE `FUN_0f8e47f0`, so its order must survive the block). A
  refused order is now held and walked on the first tick after the block lifts — `Invariants.md`,
  "A movement order outlives `block_movement`"; self-test `Pinned actor` (+`resumes`,
  `stop_cancels`). **42.10 done** (2026-09-14): wall's death is the authored "shot in the back"
  (`TRIGGER_backshot` → 730 ms → `DAMAGE_backshot`, 700 hp in a sphere the trigger lies in; the
  ded's death — the canister beside him — destroys both), and the filter RE says a blank
  `react_objects` reacts to the player in retail too (per-class fallbacks after parsing: all
  for `Explosion`/`Bomb`, humans for `trigger_alive`; the `Trigger`'s own site unfound, "nobody"
  ruled out by grsvt's blank exit trigger). Two class rules on the way: a trigger whose `shape`
  is neither box nor sphere has no volume (the original adds nothing — wall's point-shaped steam
  was charging 1 hp), and a numeric `damage_type` is GUNSHOT (the script's table miss) —
  `Invariants.md`, "A trigger is a box or a sphere, or nothing"; self-test `Damage trigger`
  (+`point`, `numeric_type`). **42.11 done** (2026-09-14): wall's final door is walled in the
  September collision mesh (`wall.ds2cm2` — two `mat_wood` faces in the leaf's plane; the May
  `.ds2cm` had only the frame; `ICollisionSystem` loads the `2` and the physics trimesh comes
  from it) and the level's exit trigger starts 19 units before it — the original's Field meets
  the actor's *capsule*, ours tested its centre, which stops 17.5 units short. A trigger now meets
  the player's capsule (and an NPC's) — `Invariants.md`, "A trigger meets an actor's capsule";
  self-test `Trigger arming` (+`capsule`, `slab`); `trace` prints the mesh face's material. The
  door the report meant was `DOOR_parad2_01`: its open leaf leaves 52.8 units, the original's
  51.2 capsule passes, ours was 55.2 because Jolt's `mCharacterPadding` (2.0) sits *around* the
  shape — the shape is now the authored radius less the padding, so a character is its authored
  `body_radius` (`Invariants.md`, "A character is its authored radius"; self-test `Barrier body`
  `radius`; five gate baselines re-recorded — the player stands 2 units closer to walls).
  **42.12 done — Phase 42 is closed** (2026-09-14): `--check` green, gate 18/18, the four
  reference scenes re-recorded (the 09-13 renderer commits, as 42.0 found for the levels) and
  `scripts/reference_scenes.sh` pinned to `export/engine` like the level gate, ASan on every
  recipe, the crane unchanged after every physics subphase (197.4/197.3/197.9/197.9, +6.1°),
  the chain `kolhoz → kolhoz_part2 → meat → meat_part2 → wall → gor` by name with 0 errors, the
  Beria scene in one run. Five roots are
  read in code before the work begins and every one is a class, not a level: `object_counter`
  parses its `add` parameter with `std::stoi` and counts to zero (three campaign scenes gated —
  the Beria door, `meat`'s second Karlson, `theatre`'s doors); a `Barrier` gets **no body** (the
  `model.empty()` skip precedes the `isBarrier` branch — ~600 authored invisible walls are
  walk-through, `sv_game.dll.c:102860` builds `AddBox(size)`); `remove_actor_item_by_classname`
  clears the C++ inventory while the player's items live in the Lua `__inventory`; every door
  swings about the **world** vertical (`DoorEntity.h:746`) so `meat`'s flat hatch spins in the
  floor plane (8 tilted door placements campaign-wide); a hidden body is out of the world since
  41.4, so the wagon's welded wheel-knockers never ride and seven knock triggers never fire. The
  conveyor finding unifies three items: the belt boxes **stand on the mesh** (their tops are the
  authored riding surface, 40 units up; on the crest they float above the mesh) — the original's
  belt is a body with surface motion, ours a bodiless zone pushing props with a force friction
  eats. Two items start with RE: the FSM `on_update` cadence (Karlson's one-tick `jump_prepare`)
  and the blank `react_objects` list (`wall`'s 700-hp `DAMAGE_backshot`). 48 mirrored placements
  (det < 0) exist in the campaign, all of them `grsvt`'s chandelier lamps.
- `yae-engine/docs/Phase43_FixPohKinoMetroTheatreKrovli.md` — the per-level method for the first
  pass over `poh`, `kinostreet` (both halves), `metro`, `met6`, `theatre` and `krovli`: 15 items,
  14 subphases. **Phase 43 is closed — 43.0–43.13 done** (2026-09-15/16; reconnaissance 2026-09-15),
  all 15 items marked with their subphase and root (two by measurement: metro's partition and its
  escalator barrier), the six "not now" items untouched.
  Two of the levels were not in the gate — `theatre` (`maps/map15`) and `kinostreet2`
  (`kinostreet2.ds2edf` on `map04`, like `kolhoz_part2`, but with a `PlayerSpawner` of its own) —
  43.0 added both: **the smoke and picture gate are 20 levels** now (smoke baseline 78 shapes;
  cameras in `LevelTestMatrix.md`), the crane reads `197.4/197.3/197.9/197.9 +6.1°` before the
  phase's first change, and `fire_io`/`io`/`props` take `#<id>` or the EDF table key beside the
  name (`Entity::edfKey`, `EntitySystem::resolve`; `io <name>` prints the key when two entities
  share the name) — `kinostreet2` spawns two `TRG_Spric26`, and a name alone can only reach the
  first. Also recorded: `kinostreetKINO.DS2EDF` (2006-10-09) is the one that loads (newest of the
  case pair); the older `kinostreetkino.ds2edf` differs only by a cut hidden `AI_dedaa` and one
  `show` link to it. **43.1** closed both `metro` escalator items: item 11 by measurement (the
  `Barrier` holds the player at the foot until the switch, the running belt is a headwind, and
  the 343-tall `TRANSP01` box's top face is the riding surface — 21.5 above the level's own
  smooth 30° collision ramp, as the original's capsule rides its `AddBox(size)` geom; 42.7 holds
  for belt volumes, `conveyorCarriesCharacter` now has the 30° ramp), item 12 on a **class**
  root: `ButtonEntity` never read the authored `switch_state` — `BUT_ESKolator` ships `true`
  (the escalator runs) and the first press was a no-op `on_switch_on`; now a `button` is
  `button.lua`'s two-state switch (born in its authored state, `use` toggles, `switch_on`/
  `switch_off` set, outputs emitted after the `turn_on`/`turn_off` clip) — `Invariants.md`, "A
  switch is born in its authored state"; self-test `Switch state`; parall's "conveyor does not
  switch off" (`TRG_konvstop`) closed by the same root. Harness on the way: `trace … skip=<entity>`
  (the mesh under a body), and `hold use`/`jump`/`fire` now register as a press (the console ran
  after the frame had read the input). **43.2** made `human_friendly` a side: the original's one
  react/skip filter reads `is_player_controlled || human_friendly` (`+0xa34`, `+0x186c`), for a
  trigger's lists and for the actor's own `enemies_*` alike — `entity/ObjectFilter` is that filter
  now, each NPC's perception candidates are the live actors its authored lists accept (it used to
  be the player only), the load-time seed goes only where the filter accepts the player, and an
  enemy in sight replaces one out of sight — theatre's gas-mask soldier now shoots the ballet
  dancer as authored (`Invariants.md`, "`human_friendly` is a side…"; self-test `Human friendly
  side`). Read on the way: the original loads `<stem>_rebuilded.ds2aim` first when a map ships one
  (six do: `alla`, `grsvt`, `kolhoz`, `meat`, `med1`, `theatre`; `LevelResolver::pickNavInDir`), the dancer dances `progon` for 22.4 s before
  he runs, and the dressing-room door is a pair whose key unlocks both leaves — a recipe that fires
  `on_open` by hand leaves the left leaf shut. **43.3**: a hidden door is a ghost like a hidden
  `RigidBody` (42.6 — the original's door is a RigidBody, `Hide` = `dGeomDisable`):
  `DoorEntity::syncBodyGhost()` from `setVisible` and at body creation, `show` gives the layer
  back; krovli's four hidden physical leaves (38 hidden doors campaign-wide) no longer stand in
  their doorways as solid bodies, `io <door>`/`trace` print `ghost`, self-test `Hidden body rides
  joint` extended. **43.4** closed poh's "unkillable old man" on three class roots, none of them the
  anchor itself (`enable` on the fly, `on_occupy` and a name in `react_objects` all worked): an
  `auto_activate` anchor's window (`is_in_fov`) was a yaw compared in the vertical plane with
  cos(fov/2) where the original (`FUN_0f8d8c80`) takes the anchor's **local X**, the 3D distance and
  cos(fov) — `fov_to_enemy = 90` is the front hemisphere (`ai::enemyInAnchorWindow`); an anchor
  authored by `react_classes` (21 of 533, theatre's two `ANCHOR_balerun*` among them) was delivered
  to nobody — delivery is the 43.2 filter now, so a name beside `skip_objects =
  $ai_controlled_actors` (5 anchors) goes to nobody and the load log says so (retail question in
  `TODO.md`); and the enemy memory was 5 s where the authored `forget_nonsensed_entity_time` is
  **120 s** (`actor_basic.properties_design`; 30.5.8's open question) — the ded forgot the player
  halfway to the second anchor. Console `anchors [<anchor>|<actor>]`, `anchor=` in `AI_TRACE`;
  self-test `Anchor enabled at runtime`; `Invariants.md`, "An anchor reaches the actors its filter
  accepts, and looks along its X"; `AnchorSystem.h` lost its unused `AnchorPoint` API. Found on the
  way: `CALLBACK_NEED_TO_RELOAD` arrives with `nil` data on every reload (`TODO.md` `general`).
  **43.5** closed kinostreet2's runner scene and key on eight layers, none of them the scene: the
  runner stood still because `Pathfinder` refused the pair silently (its one warning is capped at
  five per process, spent by the startup self-tests) — the new console `nav <actor|x,y,z> [<to>]
  [raw|los|smooth]` / `nav cells x,y,z [r] [nbrs]` then found, one under the other, that
  `nearestWalkable` took the storey above the target (the original takes the floor beneath), that
  the sight march folded a staircase into a segment through the slab (it never checked heights),
  that its direction table was mirrored on all eight directions (the file's neighbour slots run
  **clockwise from (−X,+Y)**), and that a cell's stored position is its **min corner**, not its
  centre — every path smoothing and nav-blocked sight check of the campaign had run on that
  mirror. Then: `dist_to_pos` is the original's **3D** distance from the feet (`FUN_0f8d7860`; the
  saves put the player and a walked NPC at the floor), the 30.5.1 XY flattening dropped; the
  pre-destroy hook now makes the AI forget a dying entity (`set_enemy` on a trigger the scene
  destroys — use-after-free in the chase goal); every entity table carries the original's
  `index_in_factory`/`name_in_factory` (the anchor code compares by them — without them any anchor
  was "the current one"); a walker pressed against the wall its last waypoint lies behind has
  arrived; and `PickupEntity` no longer refuses an item whose `pp_on_take` has nothing to give
  (`add_armor` with 0 points is the editor's default on ~40 keys and notes) — the basement key is
  taken and `DOOR_last` unlocks. Recorded as a consequence: poh's `AI_Ded_04` no longer seats
  `ANCHOR_Ded_01` (3D 32.2 vs range 32 — the capsule stops 3.9 off the wall the post is 5.6 from),
  a retail/physics question in `TODO.md`; smoke baseline and `vdnh1`'s picture re-recorded (its
  spawn is `nearestWalkable` of the grid centre, now half a cell over). Self-tests `Nav grid corner
  model`, `Empty pickup procedure`, `dist_to_pos 3D`; six `Invariants.md` sections.
  **43.6** closed the kinostreet2 ladder on the class: the original's `Ladder` is a field that
  meets the climber's **capsule** (RE `ds2physics.dll` `ODE::BhvCarrier::Update_Walk/Fall/Stand/
  Climb/Begin_Jump`), ours was a point with the radius as a margin on every axis — the field was
  left at `top + 25.6`, the fall put the feet back under it, and every overlap grabbed again
  (2.5 s of hop-and-regrab). Now `LadderEntity::holdsCapsule` (feet below the top face, crown
  above the bottom, within the radius across; feet level with the top = beside it), the face
  normal is the box's **thin** side towards the climber (`surfaceNormal()` read local Y — the
  thin axis is X on 22 of the 30 ladders), and the climb follows the carrier's rules: grab by
  walking into the face or falling into the volume, the look decides the vertical (towards the
  face: level or up climbs, 45° down holds; with the back to the rungs `forward` descends),
  strafe along the face, a jump is a jump, on the floor pressing away walks off — and the one
  rule added: **feet passing the top face while rising step over the edge** at the climb speed
  (`CharacterController::launch()` keeps the horizontal part as the air carry;
  `refreshContacts()` because a `setPosition()` climb leaves Jolt's ground state stale). The
  original's own mechanism — the climb through the collision step with gravity cancelled — was
  built and dropped by measurement: the shaft mouth is 64 wide with rungs 14 proud, 50 for a
  51.2 capsule, and a rigid solver stops it where ODE's soft contacts squeeze through; the
  kinematic climb keeps two rays (floor under the feet, ceiling over the crown). The plan's
  reproduction spawn was **outside the map** behind the shaft's back wall; the real recipes are
  in `LevelTestMatrix.md` (up from the pit: one grab, one exit, the floor beyond the wall). The
  42.5 meat recipe descends with `hold forward 3` now (back to the rungs), `med1` has no
  `Ladder` at all (its `BAR_Ladder_*` are `Barrier`s); self-test `Ladder top exit`;
  `Invariants.md`, "A ladder holds a capsule, and is left over its top". Found: `krovli` under
  the `asan` preset logs 1204 Jolt `IsNormalized` asserts at load (closed in 43.13). **43.7** closed
  the kinostreet2 sportsman on a loader root deeper than the reconnaissance named: not only the
  `destroy` target but the sportsman trigger's **whole `events` block** was wired onto the
  first entity of that short name — `NPCSpawner::wireIOConnections` resolved the *source* by
  name too — so `kinostreetSPORT_TRG_Spric26` fired nothing and the gas-mask trigger 3.7 km
  away fired both blocks. The original's loader (RE `sv_game.dll`, "loading entities") attaches
  each record's `events` to the object it has just spawned and looks up only targets by name.
  Now a block is wired by the record's key (`Entity::edfKey`) and a duplicated target name
  resolves to the source's own include's copy first, first-spawned only when the include has
  none (a data rule: all 165 such links in the campaign mean their own file's copy; the
  original's by-name slot lives in the undecompiled 2019 exe). 70 duplicate-named sources
  campaign-wide moved to their own entities (grsvt's `TRG_AI_06` pair, theatre's
  `TRIGGER_lift`/`BTN_octave_*`, poh's 12 sound-trigger pairs); the `matches multiple` smoke
  shape is gone from all 20 levels (baseline re-recorded, 69 shapes); self-test `I/O wired by
  include`; `Invariants.md`, "An events block belongs to the entity spawned from it". No
  sportsman exists on `wall`/`grsvt` (the plan's acceptance line was a guess). **43.8** closed
  kinostreet's lift and its doors, both classes named by the reconnaissance: the lift's call
  button `Lift_Box73` is a never-shown hidden `RigidBody` with `on_use` (34 such in the
  campaign — meat's crane fork, the grsvt/theatre piano keys), a ghost every ray steps over
  since 41.4/42.6, and the original's Use is not a ray at all but the actor's `use_dist` 2.5 m /
  `use_fov` 20° cone (RE `cl_game`/`sv_game` design registration) — now
  `PhysicsWorld::raycastUse` meets a ghost whose entity has an authored `on_use` link and
  steps over the rest (a hidden leaf in a doorway); `use` in the cabin → `Use → entity
  'Lift_Box73'`, the ride up, `Lift_Box74` at `speed −0.6` brings it down. The doors
  `Door_KinoInsidezR01/02` are authored `lo_limit 100, hi_limit 0`, and the original clamps
  `lo ≤ 0 ≤ hi` before `AddHinge` — stops [0, 0], welded panels the level opens by hiding;
  ours swung them 100° on `use`. `DoorEntity::postSpawn` clamps the same way (3 doors of 429
  campaign-wide). Self-tests `Use ray hidden button`, `Door limits clamped`; `Invariants.md`,
  "The Use ray meets a hidden button", "A door's limits are what the hinge takes". **43.9**
  closed the projector on three roots in the buttons' physics, none of them the
  reconnaissance's questions (30.7.7 had answered those): a `button` had **two** bodies — a
  static one from the "interactive" pass of `createEntityPhysicsBodies` that nothing
  referenced or destroyed, and the 37.10 kinematic collider — so the reel switch
  `RGB_Botton_Babina`, which destroys itself after the press, left a nameless body at the
  placement it shares with the lamp switch `RGB_Botton_Lamp` and every Use ray stopped there;
  the collider ignored `shapes_enabled` (the original's `false` is no geoms — the lamp switch
  stood in front of the reel switch); and `tryUse` refused any `is_enabled = false` entity
  where the original's Use checks only `is_locked` (`sv_button:on_use`) — the lamp
  `RGB_LAMP_JIV` is authored disabled and enabled by nothing. Now a button has one collider,
  a ghost while its shapes are off, released with its entity (`releaseModelCollider` from
  the pre-destroy hook; an `AnimationObject`'s too), and only a dormant door refuses Use. The
  whole chain runs by hand (reel → lamp switch → the lamp → `video2.avi`). Self-test `Button
  collider lifecycle`; `Invariants.md`, "A button's collider follows its shapes and its
  life". **43.10** closed metro's falling partition **by measurement**: `DOOR_BIG`'s box on
  its bone descends from `z[479.5..882.3]` to `[235.0..637.7]` in 2.5 s on `TRG_RRRTTT`, a
  player under it is pushed aside unhurt, the shut panel blocks, `BUT_ESKolator01` raises it
  by the backwards play (41.6) — every hypothesis of the reconnaissance refuted; the plan's
  spawn `"-3963,-2541,224"` stood *inside* the trigger and dropped it at load (recipe in
  `LevelTestMatrix.md`, metro). **43.11** closed met6's air tube on three roots, none of them
  the buoyancy curve: the density-1 column `WOLTER_veter` filling the whole shaft is authored
  `is_enabled = false` and enabled by nothing, and the original never switches a Water's field
  off (RE: its class vtable keeps the base game-object enable; `ODE::Field::Enable` has one
  caller, referenced from the trigger's vtable) — ours had it off, so a step off the −594
  platform was a 14.8 m fall to the funnel floor while the density-2 stream began at −423 ("the
  tube does not pick him up"); the "water effect" was 30.7.5's own green-blue wash (the client's
  Water class draws and tints nothing) — removed; and weightless in density 1 there was no way
  up — the original's carrier off the ground pushes along its 3D look (`Update_Fall`), so in
  water forward is now where the eye looks, capped at the swim speed. Console `look <yaw>
  [pitch]` beside `hold`; self-tests `Water field always on` (37.10's rewritten), `Character
  swims`; `Invariants.md`, "A Water's field is always on", "A character swims where it looks";
  `LevelTestMatrix.md` gained a met6 row. **43.12** — "the hands at the world origin on every
  level" — was neither a renderer nor a test artefact but the **player's inventory**: the scripts
  make every inventory item the same way (`spawn_entity`, `add_entity_to_world`,
  `add_to_inventory` — the start kit, each NPC's `init_inventory`, `weapon_firearm:on_use`'s ammo
  box), the middle step builds the item a model and a query-only body at (0,0,0), and ours left
  both there (`add_to_inventory` only appended a Lua table; an item taken off the floor left the
  world through `finalizeScriptPickup`, one made for the inventory never did) — and the weapon's
  world model was its *hands*, because `add_model(name, true)` (the original's "load now,
  instantiate first-person on the client at `on_take`"; an actor's body is `false`) had become
  the entity's model regardless of the flag, animated by `play_animation` driving the world
  instance beside the FP one. `theatre` had 19 such items at the origin (`trace 0,0,200 0,0,-1`
  hit `weapon_bottle_421`). Now `PickupEntity::stowInInventory()` is the one place an item
  leaves the world (both routes), a hidden model is never the world model (the weapon's is its
  authored `model_name`, `ItemMauzer`…), and a weapon's clip lengths come from the FP weapon its
  animation slot names, held or not — `visualize_state` times the leaving weapon's `hide` after
  the next one is the holdable (`fsm weapon on` + the new `hold slot1..9` reads 333/267 ms,
  not the 1000 ms default). Left as authored and recorded (`OriginalScriptDefects.md` C5): each
  rat's explosion `Bomb` with the `rat` model, which `actor_rat:on_init` adds to the world
  without the `hide`/`disable_shapes`/`set_pos` its own base class sends — 10 rat models at the
  origin of `theatre`. Self-test `Item in inventory leaves world`; `Invariants.md`, "An item in
  an inventory is not in the world, and a hidden model is not the world model"; picture gate
  20/20 within noise (the world lost its origin bodies, `meat`'s belt rider stops a hair
  differently). **43.13** closed the phase: `--check` green (192/192, smoke 20/20), gate 20/20 and
  scenes 4/4 with the changed frames named (dynamic props settling within noise), `--asan` OK
  plus the recipes of 43.1/43.8/43.10/43.12 under `build-asan` — which turned 43.6's krovli
  finding into a root: the 1204 `IsNormalized` asserts are `DOOR_pod04` (`door_theat_pod`, in
  both `theatre` and `krovli`) whose authored `tm` is **scaled 1.198**, and `quat_cast` of a
  scaled matrix is a quaternion of |q|² = scale that Jolt rotated with as it was (a skewed,
  larger body: a 1.2-scaled quarter turn puts a cube's faces at 70, not 50; five such placements
  in the gate's EDFs, three metro `Barrier`s at 0.9 among them) — `PhysicsWorld::createBody`
  normalizes now, self-test `Scaled placement body` (fails without it), `Invariants.md`, "A
  body's rotation is a unit quaternion"; the crane `197.4/197.3/197.9/197.9 +6.1°` after every
  subphase (a table in the doc); the chains `theatre → krovli → parall` (`TRIGGER_exit` by key)
  and `kinostreet → kinostreet2` (`TRG_kino17`, the inventory carried) with 0 errors. **43.14**
  (the user's manual pass after the close): the lift's invisible exit barrier was the top-landing
  panels `Door_KinoInsidezR01/02` — `Lift_Box73` destroys them, and a destroyed door left its
  kinematic leaf body behind (a ghost while hidden, a wall once `TRG_kino08` upstairs had shown
  them); `releaseModelCollider` takes a `DoorEntity`'s body and hinge now (15 authored door
  destroys on the gate levels, the `DOOR_glavDok08..11` after the film among them); and "the
  projector runs before the lamp is installed — one Use, reels and film, the cover gone" had two
  roots. The user's log named the first: `Use → entity 'RGB_LAMP_JIV'` — the **hidden live lamp**
  (`is_visible = false`, `shapes_enabled = false` until the lamp switch) is an animated RigidBody
  whose collider rides a bone (35.6), and 42.6's ghost rule reached only `physicsBody_` while the
  animated-platform branch never applied it at all, so the bone body was solid inside the
  projector; a Use from the right angle played the hidden lamp's clip, `on_anim_start` destroyed
  the broken lamp (the cover) and `on_anim_end` started the film. `syncBodyToState()` ghosts every
  bone body with the entity now (self-test `Animated platform ghost`). The second was the HUD: no
  `InventoryItem` pickup ever showed its backpack icon (only the classless static path did) and a
  shown icon never went away, so the lamp — taken by touch, with a key's sound — was carried unseen
  and consumed unseen. The backpack strip is the inventory now (`InventoryEntry::modelName`,
  `PlayerHUDDriver::update`, a taken item destroyed by the level leaves the inventory in the
  pre-destroy hook, the models travel in a trailing carry block — `game/InventoryCarry.h`;
  self-test `Backpack follows inventory`). The projector's order is the authored one — reel (cover
  opens), lamp switch (the live lamp into the open cover), the lamp itself (cover closes, film) —
  three presses, as the user confirms retail plays it. The reel is not in kinostreet's start kit
  (`actor_spawn_props_default.lua`: spanner, mauzer, one box — the campaign carries it from
  grsvt); the console `give <entity|name> [model]` takes a level's pickup with its `on_take` chain
  or puts an item in the bag by name (`give ITEM_lampa`, `give RIG_Bobina ItemBABINA`). And the
  reel did not spin after the film: `RGB_BabinKinoKrut`'s model has a one-frame `default` beside
  its 0.5 s `anim1`, and 36.3's `is_playing` looped the frame — `AnimationObject` now starts the
  model's first *motion* (13 placements campaign-wide, futur's spinners among them; self-test
  `AnimationObject playback` +`pose_skipped`). **43.15** (the second manual pass): "the new lamp
  is not installed" was a press going past the switches — the projector's two `RUBIL` switches
  are invisible placements inside its level-mesh housing with the shown reels' box beside them
  and the dead lamp behind, authored against the original's Use **cone** (`use_dist` 2.5 m /
  `use_fov` 20°, 43.8's RE) — now `game/UseCone.h` stands *behind* the ray: when the ray meets
  nothing that answers Use, the nearest button with shapes or `on_use`-linked body with shapes in
  the cone is pressed, no farther than a metre past the level mesh the ray stopped at
  (`Invariants.md`, "The use cone stands behind the Use ray"; self-test `Use cone`); and "the
  key does not spawn in the cutscene" on `kinostreet2` was the player walking over it — Jolt
  hands the character's weight to its ground body every frame, 1225 u/s on the 1-kg, 3-unit key,
  through the corridor floor at `Discrete` — a dynamic pickup is `LinearCast` now
  (`PhysicsWorld::setBodyLinearCast`; the 43.5 spawn-inside case is the same body; self-test
  `Pickup body swept`); and the soda machines drinkable without waiting were 43.8's ghost rule
  wider than the original — the Use ray now meets a ghost only with its shapes *on*
  (`usecone::ghostAnswersUse`; `Hide` keeps the geoms, `disable_shapes` removes them — 46 full
  cups `RIG_gaz_stakan_full_*` across the campaign are hidden and shapes-off for the 9 s fill with
  the health `on_use` linked from the start); and met6's tube lifting "too slowly" was the swim:
  the original has no swim state — afloat the carrier is in `Fall`, `Update_Fall` adds `FlySpeed`
  150 per 0.02 s step along the full look against `Water::OnEvent`'s 0.932/step damping, which
  settles at ~305 u/s up for a 60° look (~5 m/s along the look); ours was the walk speed × the
  0.3 air factor = 104. `physics::kSwimSpeed` 320 along the look now, no air factor (the same RE
  puts the original's density-2 stream at ~290 u/s where ours reaches ~1700 — left alone).
  Found and left: the live and dead lamps look alike (the bulb's
  `model_trans_2Sijiv` = `$white$ × 0.3` additive, ours the model texture) and `ButtonEntity`
  saves no runtime state — both in `TODO.md`. Five
  roots are read in the data before the work
  begins, four of them classes: `human_friendly = true` is authored on exactly **one** actor of the
  campaign (`theatre`'s `ACTOR_balerun`) and nothing in the engine reads it — in the original it is
  the actor's *side*, which is how the gas-mask soldier comes to shoot him; `poh`'s "unkillable"
  old man is authored so (`health = 50000`) and leaves by an anchor that is `enable`d at runtime
  with `on_occupy → destroy` (the open `ai_anchor` questions of 41.7); `krovli`'s locked room doors
  are `fixing = false` doors that are **hidden** until a trigger shows them (42.6's ghost rule was
  written for `RigidBody`, not `DoorEntity`); a `Ladder`'s top exit; and `metro`'s two escalator
  items were filed when a `Barrier` had no body and a `Conveyor` was a zone — today the barrier
  holds the player at the foot (measured) and the belt tops ride ~21 above the step mesh, so 43.1
  is a **check of 42.2/42.7 on a new level** (a 343-high belt box: is its top the surface?) before
  anything is built on them. Two more are read in code: `kinostreet`'s lift "stopped working"
  because its call button `Lift_Box73` is an authored **hidden `RigidBody`** with `on_use` —
  since 41.4/42.6 a hidden body is out of every ray and `PlayerController::tryUse()` is a ray
  (34 such never-shown invisible use boxes in the campaign, `meat`'s `RIG_crane1_fork_open` and
  the `grsvt`/`theatre` piano keys among them); and `kinostreet2` spawns **two** triggers named
  `TRG_Spric26` from two included files (the runtime name is the block's `name`, the file prefix
  lives only in the key) while `wireIOConnections` resolves a target to the first spawned — so
  the sportsman trigger's `destroy` reaches the gas-mask trigger. The other items are animated
  `RigidBody` platforms/decorations (`metro`'s `DOOR_BIG` with its box on a bone, the projector
  lamp behind two invisible `button`s). Six TODO items in those sections are excluded by
  the user's decision and listed in the doc. The 42.0 gate pin (`export/engine` catalog, default
  cvars) stays.
- `yae-engine/docs/Phase44_FixParallLastlevelFuturLastzlo.md` — the per-level method for the last
  four maps without a phase doc: `parall` (three halves), `lastlevel`, `futur`, `lastzlo` — 12
  items, 12 subphases (reconnaissance 2026-09-17). **Phase 44 is closed — 44.0–44.11 done**
  (2026-09-18; six subphases with fixes, one by measurement, four dropped by the user, one
  deferred). **44.0 is done** (2026-09-18): `parall`,
  `parall_part2`, `parall_part3`, `lastlevel` and `futur` are in the smoke and picture gate
  (**25 levels**; smoke baseline 83 shapes, the 14 new ones theirs; cameras and every recipe in
  `LevelTestMatrix.md`, which also gained a `lastzlo` row), the crane reads
  `197.4/197.3/197.9/197.9 +6.1°` before the first change. Between the reconnaissance and 44.0
  the user played the four maps and rewrote their `TODO.md` sections: six of the twelve items
  are **closed by the user** (mob-on-mob damage, the shelves, the turntable, the funicular, the
  cart, the environment animations), the flare colour is deferred, and the three reworded ones —
  parall's wagon *at the end of the scene*, futur's final lift, lastzlo's room lift — are **one
  class with one log line**: `I/O: lock_players → frozen=true`, after which the animated platform
  under the player leaves (carrier velocity 75–306 u/s published) and the frozen player stays
  (44.1; three verified recipes). 44.0 also measured the same wagon without the lock — the player
  rides the first second and drops off the tail when the clip accelerates to 240–275 u/s — and
  the turntable — 55° of its ≈90° at the edge, sliding inward; nothing at the centre — two more
  defects of the class. The reconnaissance was wrong in three places, found by reading the
  include trees the way the engine does (`--include_from_path` lines are skipped): `parall.ds2edf`
  loads only part1 (`parallMAN` — wagon, turntable, levers — comes only with `parall_part3`),
  `lastlevel` never loads FUNI (no 18 duplicate names, no second funicular), `futur` never loads
  `futurLOW` (no `Lift_LOW` twin); the ending chain hangs on `TRG_THE_END`, not `TRG_Door_01`, and
  `outro.avi` is 250 s with the credits inside (the user's item is now "no main menu after them").
  New item from the user, root read in 44.0: `lastlevel` loads **two** `PlayerSpawner`s —
  `SPAWN_Player` (MUSIC, 2006-08-17) 200 units *under* the tunnel floor, which the engine takes
  first by include order, and `Spaner` (GAME, 2006-10-24) on the deck of the `tapok` wagon the
  player arrives on; the original also takes the first, but from a `LuaTableIterator`
  (`lua_next`, Lua 5.0 hash order) over `entities` — 44.4 decides by simulating that order. The
  levers of parall's platforms are welds, not sliders (`Joint01/02` limits [0, 0]). **44.1 is
  done** (2026-09-18) on two engine roots, both classes: `PlayerController::update()` returned at
  `frozen_` before the character step, so a locked player (`lock_players`, a death, a cutscene)
  hung in the air while his platform left — now `updateFrozen()` steps the body with no input
  (gravity, carry, landing, camera), as the original's ODE `BhvCarrier` is stepped whatever the
  input lock; and a carrier published only its bone origin's velocity, nothing of its spin — now
  it publishes the rigid motion between two poses (`PhysicsWorld::CarrierMotion`, `spinBetween`)
  and a rider takes the surface velocity **at his feet** as the *chord* of the turn
  (`carrierVelocityAt`; a tangent step spirals outward 6 %/s at 90 °/s, Jolt's
  `GetGroundPosition()` is one frame behind and drifts 4 %/s). All three scenes run end to end
  now (parall's wagon through the turntable's quarter turn, the lock and 13 s to `next_level
  lastlevel`; lastzlo's plate to the boss; futur's lift to `TRG_End`); the two "defects" the
  reconnaissance measured on the wagon were recipe artefacts (`Barrier_m03_03`, destroyed by
  `TRG_AI_m03_22` on the authored path; the bridge not yet turned). `CharacterController::init()`
  resets the air carry (it survived a level change). Self-tests `Turning platform carries rider`,
  `Frozen player rides`; `Invariants.md` two sections; met6's baseline re-recorded (its start is a
  ride on the metro wagon round a curve) and poh's (its gate camera stands in `TRG_Damage` — the
  baseline is the death screen; the dead player now lands — `TODO.md`). **44.4 is done**
  (2026-09-18): the original spawns a level's records in `lua_next` order over the `entities`
  table — Lua 5.0's hash layout of the keys, not the files' — and "the first `PlayerSpawner`" is
  the first in that order; `assets/Lua50TableOrder.h` is ltable.c 5.0.2 for string keys (checked
  against a Python transcription), `DS2EDFParser::rankDefsByLuaOrder()` gives every def its
  `luaOrder` from a textual walk of the include tree, and `firstPlayerSpawner()` picks the lowest
  in both spawn paths — lastlevel now reads `Spaner #20; passed over: SPAWN_Player #252` and the
  player stands on the wagon (`--level` and `map lastlevel` alike); metro/theatre/lastzlo keep
  their spot. Only the spawner choice reads the order (ids, `g_world_props`, 43.7's fallback stay
  by file — `TODO.md` `general`). Self-tests `Lua 5.0 table order`, `EDF spawner by Lua order`.
  **44.7 closed by measurement** (2026-09-18): futur's whole shaft in one 150 s run — 66 s up on
  `RIG_Lift01`, the actors at the top, `ACT_Ril_10`'s real death (`fire_io … Kill`) bringing
  `RIG_Lift02` down, the player in through the railing's north-east gap, the locked ride to
  `TRG_End → next_level lastzlo`; five earlier recipe attempts hit cage walls, not engine faults.
  **44.8 is done** (2026-09-18): lastzlo's start lift was "перекошен" literally — a round railed
  platform stood on its edge in the shaft mouth — because ours built it as a dynamic body of the
  EDF's mass 100, authored jammed 20 units into the mouth, and Jolt's first frames of penetration
  recovery flipped it (the gate's 1-in-5 flake was that recovery's contact order). The original's
  `.phs` builder (`sv_game.dll.c:53113`) gives every `.phs` body of mass ≤ 0 `SetInfiniteMass` and
  the world's category and never reads the EDF mass when a `.phs` exists; 40-odd models — every
  lift, wagon, tram door, scene rig — ship all bodies at 0. `phs::Definition::pinsEveryBody()`
  now sends such a placement down the animated-platform (kinematic bone-body) path whether or not
  anything plays it: six placements on the gate levels (that lift, lastlevel's `tapok` wagon that
  had crept under the player, metro's `DOOR_BIG01`, meat's three grates), `lastzlo` 0.000 five runs
  in a row, `lastzlo`/`lastlevel` baselines re-recorded (the train sits on its rails now). Self-tests
  `Pinned phs is kinematic`, `Pinned phs shipped`; `Invariants.md`, "A `.phs` that pins every body
  is a platform, never a prop". **44.10 is done** (2026-09-18): `disconnect` is the kernel's
  "end the session" (`ds2kernel.dll` `sub_4EBF80`: client off, server stopped — the shell's main
  menu), sent by lastzlo's `m_on_end_cinema` after `outro.avi`, which *is* outro + credits + title
  card (250 s; `credits.avi` is only the menu's button); nobody received it. Now the level-wide
  `disconnect` input and `engine.process_command("disconnect")` → `GameRulesYAE::requestDisconnect()`,
  honoured at the top of the next frame (`returnToMainMenu()` — the signal arrives from inside the
  entity update). Found on the way: a coroutine whose first resume starts a clip was ticked again in
  the same frame (`wait(0)` after `play_video` came due at once — grsvt's `gaz` waits 5 s first and
  never showed it), so `m_on_end_cinema` fired at the outro's first second — `EntitySystem::updateFull`
  takes a `mayTick` predicate now, `!cinematicPlaybackActive()`. Self-test `Disconnect request`;
  `Invariants.md`, "`disconnect` ends the session, and a clip's coroutine waits for the clip".
  **44.11 closed the phase**: `--check` green with 25 levels, picture gate 25/25, scenes 4/4,
  `--asan` plus the recipes of 44.1/44.4/44.7/44.10 under `build-asan` (0 reports), the crane
  unchanged after every physical subphase, the chains `parall_part3 → lastlevel → futur → lastzlo →
  menu` by name with 0 errors. Two harness changes: `YAE_SPAWN_POS`/`YAE_SPAWN_YAW` now apply to
  the **first level of a run only** (a transition afterwards spawns as the campaign would — the
  override had dropped the player into the void of the next map), and poh's gate camera moved out
  of `TRG_Damage` (its baseline had been the death screen since 42.0) to the water's edge. The
  four reference scenes were re-recorded: `ward`/`shop`/`yard` had drifted from their 09-14
  baselines *before* Phase 44 (identical numbers at 43.15's source; shop's old baseline shows a
  streaked brick relief that no source, catalog or cvar reproduces today — recorded in `TODO.md`
  `general`, cause not found).
  The `general` tail (authored `damage` table, `ButtonEntity` save state, NPC move sound twice,
  `CALLBACK_NEED_TO_RELOAD`, Use-grab of dynamic bodies) is left for Phase 45 and listed there.
- `yae-engine/docs/Phase45_FixGeneralMet6Krovli.md` — the per-item method applied to `docs/TODO2.md`:
  twelve campaign-wide items (player speed as authored + cvar, spawn order by `lua_next` for the whole
  list, look under `lock_players`, a disabled actor is invisible, `calc_target_dir` with pitch, the
  `g_diff_levels` damage multipliers, the sniper scope, missiles on physics, explosion/roll camera
  effectors, perception, conveyor material swap, debris vs characters, rat death chunks) plus `met6`'s
  belts and `krovli`'s door (the Use-grab of 41.5) and wires — 15 items, 18 subphases (45.0–45.17).
  **In progress**: 45.0 begun (crane `197.4/197.3/197.9/197.9 +6.1°`, `--check` green, speed
  before 397.6 u/s), **45.1 done and accepted by the user 2026-09-19** (manual pass: walk 150, Shift 400, the re-timed recipes) (two attention
  points in the doc's header are closed only by the user, and rolled back on a bug: the crane's
  `verletStretch` after 45.16, and the gate baselines/`hold` recipes after 45.1/45.4/45.16).
  45.1: the retail player walks at `walk_forward_speed` = **150 u/s** and has no run — read in
  the disassembly, not the export (`set_walk_speed` = vtable slot `+0x1e4` → `[actor+0x2164]`;
  the only runtime write is the carrier's creation, `0x0f88b21e`, from `walk_forward_speed`;
  `run_*` never read; `move_accelerate` unbound) — `game/PlayerSpeed.h`,
  `PlayerController::applySpeed`, cvars `pl_walk_speed`/`pl_run_speed` (0 = authored; `400`/`700`
  bring the harness speed back) and `pl_sprint` (Shift runs — on by the user's decision, an
  exception: retail's `set_move` drops the client's accelerate bit — at `pl_run_speed`'s default
  **400**, the engine's old walk; `0` = the authored `run_forward_speed` 200), self-test
  `Player speed from design`, every `hold
  forward N` recipe in `LevelTestMatrix.md` re-timed (old N in brackets); found on the way: the
  actor sets the carrier's `FlySpeed` to 100 where 43.15 assumed 150 (`TODO.md` `general`).
  **45.2 part 1 done 2026-09-19**: the check of `luaOrder` against the retail's own `level_start`
  saves found a root above the order — **the include rule** (`DS2EDFParser::resolveInclude`,
  mirrored in `sdk_dump.ts`): exact spelling beside the including file → exact at the levels root
  → exact anywhere → newest case-insensitive; the tree is three paks in one place (base under
  `<map>/`, patch 0 beside it, patch 1 at the root) and the engine had loaded the base's pre-patch
  copies of 16 includes on 13 maps (every `*sound`, `lastlevelFRODO`, `gorkonecCRAY`, `kinosound`,
  meat's `m03a`) — gor's base sound file alone carried 9 medkits and 10 boxes retail never had.
  With the right files the Lua 5.0 order matches the saves 100 % (gor 224/224, meat 559/559,
  kolhoz 395/395, med1 564/564; `WORLD` first). `--dump <edf>` prints `_engine_only.lua_order`;
  self-test `EDF include resolution`; `gor_part_2`'s baseline re-recorded (a base test box in
  frame); `lastzlo`/`met6` now load two `WorldProps`. **Part 2 done by the user's decision**: the
  whole spawn list is the original's (`DS2EDFParser::orderDefsAsTheOriginal`, `WorldProps` pushed to
  the front as met), so ids, `index_in_factory`, `g_world_props` and 43.7's fallback follow it;
  kinostreet2's `TRG_Spric26` pair is ids 29/166 now; the crane unchanged; `parall_part3`'s
  baseline re-recorded (fence planks settling) — both re-recorded baselines await the user's eye.
  Found by the user's acceptance pass and fixed the same day: gorkonec's soda cups were never
  drawn — `classifyModelTemplate` gave model surfaces no `sort_value` (default 5), so the cup
  (`model_gaz_stakan_glass`, authored 8, additive) drew before the machine's translucent front
  panel (`def_trans_refl_Vx`, 8, blend) and was painted over; `registerModelScene` now reads the
  template's `sort_value` from the `.mat` library (`SceneResources::setMaterialLibrary`,
  `applyModelTemplateOrder`; self-test `Model template sort`; `ward` scene re-recorded). The
  instant heal there is authored (`delay = 0` in every copy of `gorkoneccray`).
  **45.3 done**: the look under a freeze — `lock_players` leaves the eyes free (the server locks the
  carrier's move mask, `Look` is a separate call and `block_turn` a separate property no scene
  sends), a death or cutscene freeze holds the view, and no freeze banks the mouse (`setFrozen(frozen,
  lookFree)`, self-test `Frozen look`); retail agrees (the user: lastzlo's lift, the locked player looks around) — accepted.
  **45.4 done**: an actor born `is_enabled = false` is hidden and capsule-less whatever its
  `is_visible` (the retail saves: 21 of 21 such actors recorded `is_visible = false` — reversing
  37.8's inference, which was about a prop), `enable`/`ai_activate` bring it in; self-test
  `Disabled actor hidden`; the gate 25/25 unchanged.
  **45.5 done**: `calc_target_dir` without a target is the shooter's look **with pitch** (the
  thunder's fireball lands where the camera points: floor at −30°, wall at +25°; self-test
  `calc_target_dir pitch`). **45.6 done**: `g_diff_levels` — read by nobody until now — multiplies
  a **missile's** damage by the *shooter's* side and the DS2 damage code, as the original's one
  reader does (`FUN_0f8d39b0`; hitscan, `Bomb`, `Explosion`, the `damage` command are not
  multiplied): the player's thunder on NORMAL is 3.5 × 3.6 = 12.6 (measured on metro's soldier),
  an NPC's missile ×1.2; the table is built by `sv_game_init` so it is read after that hook; a
  loaded save's difficulty now reaches the rules; console `difficulty [name]`; `disp_multiplier`
  parsed, not applied (`game/DifficultyTable.h`, self-test `Difficulty table`; `Invariants.md`, "A
  missile's damage is multiplied by the difficulty table").
  **45.7 done**: the sniper scope — `cl_<class>:on_init` used to run on the one merged object,
  so `self.on_enter_zoom_in` was the *server's* handler registered twice and the client's (the
  scope key) never ran; now it runs on the client's view (`__yae_client_view`: methods through
  `cl_<class>` first, data/writes the entity's) and `FSM::addState` keeps a second handler set
  for a different function under an existing name (the same function again is a no-op — no
  double `on_update_fire`); the HUD shows the group's `__left`/`__right` fields with the scope, over the whole HUD (an
  element inherits its group's `z_order`, the twice-defined group its higher one — user's call);
  `hold altfire|reload`; self-test `FSM double registration`; `Invariants.md`, "FSM
  self-transitions" extended.
  **45.8 done**: grenades and Molotovs — the flight was already ballistic (first contact within
  0.3 % of `v²sin2θ/g`), the body was not: the model flew with an identity pose (a stick grenade
  upright in the world, the bottle never turning) and bounced on engine numbers that killed 40 %
  of the speed per hit. Now a missile has a pose (the shooter's basis) and a spin (the authored
  `m_angular_velocity` × [0.5, 1.5] per component, rad/s, as `sv_game.dll` `FUN_0f8a0870` sets
  it), bounces as a Coulomb contact on a solid sphere with its `material_default`'s authored
  numbers (`inter_grenade` 0.5/0.3), rolls with friction feeding the spin, lies on its side at
  rest; a ground probe finds rolling contact the velocity sweep cannot; self-test `Grenade
  ballistics`; `Invariants.md` 36.6 extended. A Jolt body (the plan's option b) was not needed.
  **45.9 done**: camera effectors — a blast's authored `effector` (missile default
  `camera_explosion`, Bomb/Explosion `-unknown-` = none) now reaches the camera by
  `object_quaker`'s distance rule (`game/BlastShake.h`), the `roll` class leans the view by the
  body's side speed (own + carry, world units; strafes and poh's tram saturate the authored 2°),
  the view got a roll channel, and the `quake` was re-read from the binary: `amplitude_h` is an
  angle in radians on pitch and yaw, `amplitude_v` a position on all three axes, fading
  linearly — 30.7.4 had read both as position, so explosions (0.1) were invisible. `fx` prints
  the live offsets; self-test `Blast and roll effectors`; `meat`/`met6` baselines re-recorded
  (the lean) — for the user's eye; `Invariants.md`, "A blast shakes the camera it reaches…".
  **45.10 done**: perception — the sight cone was `cos(view_fov/2)` on the yaw, half the
  authored width; the original's visibility slot (`0x0f86ebe0`, `is_object_visible`) is
  `dot(look, centre − eye) ≥ cos(view_fov)` in 3D — 90 is the front hemisphere, the anchor's
  convention — and the chase (`FUN_0f8e47f0`) completes only within `chase_dist` *with the enemy
  in sight*, else walks to the last-seen position (ours completed on distance and stood behind
  cover "just looking"); `view_fov ≥ 180` is all-round; `ai_trace` prints `AI_GOAL chase` and
  `AI_MOVE`; self-tests `Authored perception` (rewritten cone), `Chase ends only in sight`;
  `Invariants.md`, "An actor sees the front hemisphere of its look…". Sound untouched.
  **45.11 done**: the belts that would not stop — `NEBO` (`WorldProps`) was a bare `Entity`
  with no `replace_material`, so parall's level-template swap (`custom_conveyor1_forward` →
  `_off`) went nowhere: `entity/WorldPropsEntity.h` + `SceneResources::swapLevelTemplate`
  rebuild the level surfaces' params from the new template; and `play anim1 once` over the
  running loop (metro's `ESKOLATOR`) was swallowed by the play handler's keep-alive guard —
  the same clip asked for in another mode now changes its mode in place
  (`AnimationPlayer::setPlaybackMode`), the cycle plays out and stops. Self-tests `World
  material swap`, `Play once ends a loop`; `Invariants.md`, "`replace_material` on
  `WorldProps`…".
  **45.12 done**: debris pieces are corpse bodies to the player's capsule (`DebrisSystem` marks
  them; the original's debris are `RagDoll`s under the same `ph_ragdolls_players_no_collision`),
  NPCs meet them as before (`Ragdoll::Create` sets no ODE category — the carrier's mask 7 finds
  them); self-test `Debris ignores player`; `Invariants.md`, "Debris is a ragdoll to the player".
  **45.13 done**: the rats' death chunks — a script-spawned `RigidBody` (every rat's `Bomb`,
  actor_basic's ragdoll bomb) got no fall-apart callback, because the wiring ran once at load
  over `allEntities`; `onEntityAddedToWorld` wires each runtime one now and the rat drops its four
  `rat_debris` pieces; `Rat_Blood.lua` is an effect template for Phase 46. Self-test
  `Script-spawned bomb debris`; `Invariants.md`, "A runtime RigidBody breaks like an authored one".
  **45.14 closed by measurement** (2026-09-20): met6's belts, fans and turbine play their
  authored `anim1` from their triggers (the belt clip is a 1.5-unit flutter, the two bands are the
  two runs of one loop — `hide` removes both); the wheel `RIGID_koleso01` is sent `anim_play anim1`
  while `met_koleso` has only `default`, and the original's handler (`sv_game.dll` `FUN_0f8aa390`:
  clip length by name 0 → no controller) plays nothing for it, as ours does — no `default` auto-play
  exists for a `RigidBody`; self-test `Anim play on show`; `Invariants.md`, "An `anim_play` naming a
  clip the model lacks plays nothing"; the retail question (does the wheel turn?) and the `mehan/`
  `.phs` lookup are in `TODO.md` `met6`. Harness: `screenshot` captures the state after the
  commands that follow it in the same tick.
  **45.15 done** (2026-09-20): the Use-grab — the original's actor Use hands a `pickable` body
  lighter than `ph_hold_mass` to `ODE::BhvCarrier::Take`, and the Hand drives it to feet + 116 up +
  90 along the look with `Object::Controller`'s PD servo (kp 1250 /s², kd 35 /s, the orientation
  kept relative to the look), a second Use drops, `ph_throw_on_drop` throws (one 20 ms step of
  `look × ph_throw_force × 1e6`) — `game/HandCarry.h`, `PlayerController::tryUse/dropHeld`,
  `scripting/CarryLuaAPI` (`arms_has_thing`, `execute_action(ACTION_USE)` — the thunder's right
  button works), `game/HandWiring.h` (the `ph_*` vars from the autorun/`engine.set_var` store, the
  drop on an item take, death, destroy, level end); a `fixing = false` door has no motor by Use
  any more (`sv_door:on_use` is empty; the leaf is grabbed, `open`/`close` keep the motor) — krovli's
  `DOOR_room_l/r` open by hand; self-tests `Use grabs a body`, `Use grabs a door leaf`;
  `Invariants.md`, "Use takes a pickable body in hand". Found and left in `TODO.md` `general`: a
  physical door's `close` overshoots to the other stop (pre-existing).
  **45.16 done, awaiting the user's acceptance** (2026-09-20; the crane and krovli's wires against
  retail — a bug rolls it back whole): a `Rope` is `ODE::Cloth` — links rest at span/segment ×
  `strain` (0.9 = pre-tensioned, not "90 % stiff"), bend links at 2× × `bend` and push apart only,
  five passes of `k = r²/(d²+r²) − 0.5` per fixed 20 ms step, gravity 1050, the wind a per-step
  random horizontal direction that averages to nothing; krovli's wires sag 58–62 instead of 250,
  the crane `197.4/197.3/197.9/197.9 +6.1°` unchanged (its numbers are the cables' and hinges',
  not the chain's); `ropes <name>` prints `sag`; self-test `Rope rest length is strained`;
  `Invariants.md`, "A rope's link rests at `strain` of its span".
  **45.18 done** (2026-09-20, an item the user added after accepting 45.16 — a mob's idle heard
  clearly at level start from across the map, then "a motor heard through walls at 20–50 m"):
  three roots — the sound system's attenuation was miniaudio's clamped inverse (a sound never
  falls below `min/max` of its volume), `add_sound(name)` without distances (every lift, door,
  button) defaulted to 2/100 m where the original's source is born 1/15, and every actor's idle
  is played by its `on_init` before the listener exists. The original (`ds2soundsystem.dll`
  `sub_1000C480`) computes the gain itself — `t²·min/d`, or `t²·0.5` for `old_distance_model`,
  **zero at and beyond `max_dist`** — and ours does now, every frame; a 3D sound asked for before
  the first `updateListener()` is not started. The sound's metre is 64 units (the client's
  ×0.015625 and its debug draw against `max_distance`, `cl_game.dll.c:67454`) — one iteration
  tried 100 so gor's spawn would hear its wind (20.6 m from a `max_distance 20` source) and the
  user's ear refused the wider radii; that wind at the spawn is the open retail check. The old
  model's flag is on every sound object at birth and halves everything, head sounds too — the
  overall level is now the original's ("too loud, the slider does not help"). `sounds`
  prints distance and gain; self-test `Sound distance law`; `Invariants.md`, "A sound is silent
  beyond its `max_dist`"; smoke baseline re-recorded (load-time sounds no longer attempt to load).
  **45.19 done** (2026-09-20, an item the user added — the weapon wheel skipping weapons and
  the hands staying on an emptied weapon): `InputCommands::endFrame` copied the wheel impulse
  into `previous_` before clearing it, so every second notch of a quick scroll was swallowed —
  now notches are counted and each is a `select_weapon(NEXT/PREV)` step (`wheelSteps`,
  `hold next|prev`); and `select_holdable` from the scripts (`select_weapon(BEST_WEAPON)` on
  an empty clip) never reached the first-person model — `WeaponCoordinator::syncFPToLuaHoldable`
  reconciles the hands with Lua's holdable once a frame. Self-test `Wheel notches`;
  `Invariants.md`, "Every wheel notch is a step, and the hands follow the Lua holdable".
  **45.19b** (the user: still not the retail order): retail's wheel is the script's `select_weapon`
  by `priority` (RE `sv_game.dll` `FUN_0f8833a0` → the function bound as `select_weapon`), and the
  *shipped* copy wraps (NEXT past the top retries from 0, PREV below the bottom from 1e6) —
  `cycleWeapon` makes that second call when the script answers `false`; self-test `Weapon
  switching` +`wrap`. **Found on the way, the user's decision (`TODO.md` `general`): the engine
  reads the pre-release script dump, not the shipped scripts** — `scripts_engine.pak` /
  `scripts_you_are_empty.pak` (entries dated 2006-10…11, the release's) differ from the loose
  `scripts_*/` trees (2006-05…09) in 138 files, all but one newer in the pak: `select_weapon`'s
  wrap, `g_diff_levels` HARD (45.6 read the dump's 1.4/0.6; shipped 1.5/0.5), maxim/thunder_fire `priority 0.5`,
  `ui_ini.lua` (the key-assign box), `materials_pairs.lua`, `coroutines.gorkonec`, and
  `channel = "effect_hit"` on 120 effect files (Phase 46). **The tree is the paks now** (the
  Steam install has nothing else; the original's file index — `ds2base.dll` — is by lower-cased
  basename, newest mtime wins, a zip entry carries the archive's mtime). The first unpack died
  on `gorkonec`: the shipped `coroutines.lua` includes a level file that indexes the renamed
  `coroutines.gorKonec`, and with one textual `DoFile` chunk stock Lua would lose the twelve
  levels after it — the original does not, because **DS2's Lua never raises on indexing a
  non-table** (`ds2scriptsystem.dll`: every basic type has an empty default table, `luaV_gettable`
  has no `typeerror` on that path, `luaV_settable` raw-sets into it) — `scripting/DS2TypeTables.h`
  reproduces it on every state (self-test `DS2 nil indexing`; `Invariants.md`, "The shipped
  scripts are the paks, and a nil indexes as an empty table"). Consequences: HARD is 1.5/0.5,
  the maxim (0.5) is what a direct start of `lastzlo` holds after the level strips the kit
  (baseline re-recorded), `set_req_fixed_update_rate` bound, the manifest re-recorded (497,
  the paks are the reference; the dump survives in `yae-sdk/Projects/test/scripts`).
  **45.20 done** (2026-09-20, the user's item — env/hit/scream sounds louder than weapons and
  the menu, "no fade, a cut at the edge"): the master is the endpoint's and now measured
  (`sounds` prints `master`, `mix peak`, clipped share, `sounds volume <v>` for an A/B); the
  distance law is the original's `t²` re-read in the disassembly (steep by design, zero at
  `max_dist`; OpenAL's own attenuation is disabled by a 1e6 reference distance); the balance
  root is **`snd_reuse_same_voices`** — the same file within 150 ms and √3 m restarts the
  playing voice instead of adding one (`SoundSystem::reuseSameVoice`; eight pellets, one hit
  per variant); self-test `Event sound retrigger` rewritten; `Invariants.md`, "A sound asked
  for twice in 150 ms at one place is one voice". Then the user's examples (med1's clock at
  0.20) gave the loudness root: the client turns an authored `volume` into the voice's gain as
  **`clamp(1 + volume, 0, 1)`** (`cl_game.dll` `0x10076316`, `sub_1000BEE0`'s clamp) — `-0.7` is
  0.3 and the hundredths-of-a-decibel convention (`-300 … -2100`, ~200 sources) is silence in
  retail; `ds2VolumeToGain` is that now, a silent source gets no voice — `Invariants.md`, "An
  authored `volume` is `1 + volume`, clamped".
  Reconnaissance 2026-09-19 on HEAD `4cae0ed`. Seven roots are read in the data before
  any run: the authored player speed is `actor_player_design.lua` 150/200 with no run key bound in
  retail; the original's reference saves record every actor authored `is_visible = true, is_enabled =
  false` as invisible (21 of 21; 368 such actors in the campaign); `calcTargetDir` without a target is
  yaw-only; `g_diff_levels` (ELECTRO ×4.5 for the player) is never read; a belt's motion is a
  `replace_material` on `NEBO` (WorldProps) — a level-template swap; debris are ragdoll parts and
  `ph_ragdolls_players_no_collision` only reaches corpses; a rope is `ODE::Cloth` whose link rest
  length is span × `strain` (0.9 = pre-tensioned), not a stiffness — the solver is read in full
  (`ds2physics.dll.c:26000`). The reference saves also expose the original's whole spawn order
  (`Save19`: `WORLD` first, then hash order), the check 45.0 runs before 45.2 touches any id.
- `yae-engine/docs/Phase46_EffectsParticles.md` — **effects and particles** (plan approved by the user
  2026-09-18; **Phase 46 is closed — 46.0–46.9 done 2026-09-21**; Part B — effects v2 — is
  **Phase 51** in `docs/Roadmap.md`, a sketch). 46.9 closed it without a code change: `--check` green (243/243, smoke 25/25),
  size ceilings for the phase's five big files with reasons, `--asan` with the recipes of
  46.4/46.6/46.7/46.8 at 0 reports, the picture gate 25/25 twice with identical numbers
  (`meat`/`gor_part_2` re-recorded for a ≤ 6/255 prop-settle residue since 46.7), scenes 4/4,
  the crane unchanged; `perf` on `meat` at 3440×1440 — `game:effects` 0.021 ms CPU,
  `render:particles` 0.032 ms CPU / 0.019 ms GPU for 61 instances and 1152 particles (the
  plan's ≤ 0.3 + 0.5 ms budget with a tenfold margin; `gorkonec`'s full-frame fog sprites are
  the GPU maximum at 0.039 ms); `Invariants.md` gained the 46.1–46.3 section ("An effect is a
  template of four channels…"), `OriginalScriptDefects.md` C7–C10 (`pfx_electro_smog` does
  not parse, `angulat_vel`, poh's missing `pfx_smoke01_blue/red`, `bland`/`WLM_WooD.tga`
  fallbacks), `LevelTestMatrix.md` the effect recipes, `TODO.md` the phase's leftovers
  (contact effects of props, bloodmark scale, bone effects, retail references). 46.8 is `object_flare` — the
  original's ds2render flare object read whole: `flares.lua` (`test_flare` + `flares_default`;
  `flares_custom` is loaded by nothing) parsed by `assets/FlareTableLibrary` with the client's
  vocabulary (flags byte bit 0 `dist_invariant` … bit 7 `nearest`, `FLARE_BL_ADD/MODULATE/BLEND`
  = 0/1/2 = ONE/ONE, DST_COLOR/ZERO, SRC_ALPHA/ONE_MINUS); `effects/FlareSystem` steps twenty
  flares a frame, each at most every 20 ms, a plain element lit by a **ray through everything
  solid but the characters** (`PhysicsWorld::flareRayBlockedZUp` — the server's trace object the
  renderer is handed, `ODE::World::Trace` mask 0x43: level, props, kinematic `.phs` bodies, doors;
  not actors, corpses, sensors, barriers, ghosts — 46.9b, after the user's "flares through the
  wagon": 46.8 had read the level mesh alone, and lastzlo's wagon cone shone through the
  boss-room door) with the visibility following at 0.005/ms, a `glow` element depth-tested
  instead (its box vs the frustum, no ray); draws through the ParticleRenderer with colour × fade(d) × visibility,
  `offset` along the line to the view axis at distance d, size × d when `dist_invariant`, world
  up under `z_align`, no fog, no depth write, the `depth_test` flag read by nobody; the fade map
  is `map[key] = value` (the default table is always lit). 172 placements on `meat`/`meat_part2`/
  `futur`/`lastzlo` only (none on `kolhoz`/`med1`); `FlareEntity` hides on
  `show`/`hide`/`enable`/`disable`/`is_visible`; `engine.create_flare` & co. bound;
  `AreaHide.hide_flares` is dead code in this build (its box function has no caller). Console
  `flares entities` per-flare readout + summary, `io <flare>`; self-tests `Flare tables`,
  `Flare element offset`, `Flare entity inputs`, `Flare ray solids`; pass `render:flares` (0.012 ms on futur);
  `futur`/`lastzlo` baselines re-recorded; `Invariants.md`, "A flare is lit by a ray through the
  level mesh…". 46.7 is the engine channels — every
  effect the engine plays itself (a hit, a breaking prop, a blast, a missile's `attached_effect`
  and `explode_effect_name`, a lit fuse) is the template played whole as an anonymous one-shot
  of the coordinator, as the original's five creators do (`FUN_0f8d2b10` hit with +Z the normal,
  `FUN_0f8aa7d0`/144960 in the object's matrix, `FUN_0f8f5500`/93908 riding the object); the
  **presets are gone** (`ParticleManager` is the frame's draw list now, moved with
  `ParticleRenderer` to `effects/`; `ParticleEmitter.h`/`ParticleTypes.h`, `uPreset`,
  `game:particles`, the VisualEntity emitter map deleted); a material pair is selected by the
  contact's speed windows (`n_range`/`t_range`, inclusive — a bullet is (1, 1), an actor's step
  (0, |v|/2000)), not by a roll; a prop's own contact effects (`coll_wood_box_*`) have no reader
  in the server code and are not invented. Self-tests `Material pair by speed`, `Hit effect
  plays template`; `Invariants.md`, "An engine channel plays the template whole…". 46.6 is the script API — the ten
  entity methods on the coordinator (`EntityMethodsExtended::registerEffectsExtAPI`; the
  `LuaGameAPI` stubs, `__effect_*` tables, `createMuzzleFlash` and the C++
  `load_shoot_effect`/`visualize_shoot_effect` gone): `create_effect(tid, model, ref_point)`
  attaches to the **tag shape's whole matrix on its bone** (`actorTagMatrixLocal`,
  `FirstPersonWeapon::getTagWorldMatrix` for the FP model via `game/EffectWiring.h`,
  re-resolved after the weapon's emit with the frame's camera), created active as the original
  does; `reset_effect` = reset + activate (message 0x24); `release_effect` = anonymous,
  `destroy_effect` = now. An NPC's `fire_trace` tenth argument plays the tracer one-shot at the
  shot's origin along the shot (`FUN_0f8d2b10`); the player has no tracer in retail. Found on
  the way: the original's base object calls the script's **`on_inslot_enable/disable/destroy`**
  after those inputs — ours let the C++ handler shadow it, so the flamethrower's nozzle
  (`actor_flamethrower:on_inslot_enable`) never lit by a trigger; `EntitySystem::setInslotCallback`
  → `LuaEngine::callEntityInslot`, and `fire_io` now takes `EntityIO::deliverInput` like an
  authored link. Self-test `Effect script API`; `Invariants.md`, "The script's effect is a
  coordinator handle…". 46.5 is the placed effect —
  `entity/EffectEntity` for both `Effect` (735) and `ParticleSystem` (42): the instance created at
  spawn from `file_name` at the `tm` verbatim, `active` → activated (shown), `is_visible = false` →
  hidden, `is_enabled = false` → hidden and inactive until `enable`; the RE swapped the
  reconnaissance's two classes (`Effect` = ctor `FUN_0f8f3190`, `ParticleSystem` = `FUN_0f8d15a0`)
  and settled the one difference — **`Effect::activate` reads `parameters.reset` (true = reset +
  activate, message 0x24), `ParticleSystem` never does** — which is how the 556 authored
  `activate {reset = true}` re-arm scene explosions whose `time`-windowed sources fired at load in a
  hidden instance (the PSys clock runs from creation, active or not). `parent`/`parent_point` (70,
  all RigidBody/Bomb parents) ride rigidly from the authored pose, bound on the first frame the
  parent exists; the editor's `shape`/`size` gizmo is not read. Particles draw from their own
  generator (`PapiRandom::seed`) so a birth no longer shifts `rng::global()`; `effectCoordinator_`
  is declared before `entitySystem_` (onDestroy releases into it). Gate re-recorded 25/25 (only
  `gorkonec`/`parall_part3` beyond noise — authored fog) and the `shop` scene (a lamp's
  `pfx_cone2_dust` over the camera); poh's `pfx_smoke01_blue/red.lua` do not exist in the tree (a
  WARN, retail misses them too). Self-test `Effect entity inputs`; `io <effect>` prints `effect:`;
  `fx stats [all]`. 46.4 is the instance and the coordinator —
  `effects/EffectInstance.h` + `game/EffectCoordinator` (a coordinator beside the others, not the
  facade): the original's instance read in `cl_game.dll` (`FUN_10028e20`/`FUN_10027ba0`/
  `FUN_100279c0`/`FUN_10026720`/`FUN_100266a0`) — **born hidden and inactive**, `activate` shows the
  instance, runs the `switchable` sources, replays the sound and lays the decal (`probability`,
  the surface normal = the matrix's +Z, outward — 46.6 read the hit templates), `show`/`hide` carry the sound, the sound file is drawn **once per instance**, `reset` kills
  every particle, a lost parent freezes and deactivates, only *anonymous* one-shots are collected
  when no longer alive (`light.duration > time` ∨ sound playing ∨ `auto_delete > t`); **the light
  channel is a clock and nothing else in retail** — no code reads `range`/`color`, so no flash is
  drawn (faithful-first; the flash is a `TODO.md` `general` item by the user's decision). An
  attachment to an actor gets 37.13's quarter turn (a flame authored along +X leaves the character
  forward) and the player's `transform` is rebuilt each frame at last (`syncPlayerEntityPosition`);
  `ParticleManager` draws the instances through `setSystemProvider`; `fx spawn`/`attach`/`inst`/
  `stats`/`clear` on the coordinator (an actor without a tag gets the effect at its eye); self-tests
  `Effect instance clock`, `Effect attachment`, `Effect light is a clock`. 46.3 is the renderer —
  `particles/ParticleRenderer` rewritten as batches of the original's six sprite types (read in
  `ds2render.dll` `FUN_10033aa0`: **`rotation` turns the texture, not the quad**, and a rotated UV
  square wraps with GL_REPEAT; `velocity_align` runs *from* the particle `sx + |v|·kx` along v̂;
  `lines` are a camera-facing ribbon prevPos → pos of half-width `size.x`; `add = ONE/ONE`,
  `modulate = DST_COLOR/ZERO`, `overlay = ONE_MINUS_SRC_ALPHA/ONE`; depth test on, mask off by
  default), flipbook, `tex_env`, alpha test, the level's fog (attenuating `add`), the presets kept
  pixel-identical as `preset` batches; GL self-test `Particle quad geometry`. 46.2 is the PAPI simulation —
  `effects/Papi.h/.cpp`, every action read from `ds2physics.dll.c` and cited by address (the
  27-word particle record with DS2's `prevPos`, `colliding` as a per-particle *probability*, the
  inclusive age filter and which actions skip it, swap-with-last removal, PAPI 1.x's NRand from
  the disassembly, `source_vel` as a multiplier of the emitter's velocity, **`reset` kills every
  particle**), `ParticleManager::spawnTemplate` as the bridge (stepped, collided through
  `PhysicsWorld::particleRayZUp`, drawn by the old billboard), `fx spawn`/`attach`/`stats`/`clear`
  on it, seven `Papi *` self-tests. 46.1 is the template parser —
  `assets/EffectTemplate.h` (the four channels as data, in the binary's vocabulary),
  `EffectTemplateParser`, `EffectTemplateLibrary` (the tree once, `get(name)` as the original
  resolves: `.lua` appended, base name anywhere, the **newest** of 14 duplicated names),
  `--dump <x.lua>`, `fx info <tpl>`, self-test `Effect template grammar` (266/193/423,
  `pfx_expl01`/`pfx_flamethrower1` field by field); `HitEffectLibrary` is a thin wrapper now.
  Read in the disassembly: **`time = {a, b}` is start + duration** (both stored as authored,
  `papi::system::update` tests `a ≤ t ≤ a + b`), `custom_render`/`use_fixed_color`/`use_tm`/
  `sprite_axis_align_*` do not exist in the binary at all, `tex_env` ∈ {add, mul, mul_scale_2x},
  an unknown `decal_type` (`replace`, `bland`) is blend. 46.0 gave the harness: `bash scripts/effects_survey.sh`
  (Lua 5.4 over `effects/**` and every `.ds2edf`; `--record`/`--check` against
  `scripts/effects_survey_baseline.txt` — the reconnaissance numbers reproduced: 266 files / 193
  systems / 423 groups, 777 placements, plus the oddities list for `OriginalScriptDefects.md`), the
  console `fx` family in `game/EffectCommands.h` (`fx list [mask]`, `spawn`, `attach`, `stats`,
  `reload`, `show` beside the 30.7.4 `pp`/`eff`/`stop`/`list pp|eff` — every answer says
  `preset …, legacy player not yet` until 46.1–46.4), `perf counters`' `particles:` line, and
  `tests/referenses-effects/` for the retail recordings of Appendix A (the user's part, none yet).
  Found on the way: `DebugCoordinator::spawnTestParticles()` puts three preset emitters at the
  world origin of every level (dev builds) — goes with the presets in 46.7. Decisions: faithful-first
  (the original's quirks are reproduced and recorded in `Invariants.md`), all of 46.0–46.9 in
  release 1, particles stay in the picture gate, retail reference recordings per the doc's Appendix A
  (priority: muzzle flashes, flamethrower jet, wind), budget on `meat` ≤ 0.3 ms CPU + 0.5 ms GPU. Part A is the **legacy system** for the first
  release: the original's effect templates (`effects/**/*.lua`, 265 files, 193 particle systems / 423
  groups; channels `partice_system_desc` (sic), `light_desc`, `sound_desc`, `decal_desc`) played as the
  original played them. The RE settled the model: the particle code is **McAllister's Particle System
  API** (`namespace papi` in `ds2physics.dll`, stepped once per client frame by `World::UpdatePSyses`,
  collided by a ray `posB → pos` in the ODE world) with DS2 additions (`bounce2`, `source_from_group`,
  `set_position`, per-action `time`/`filter`/`switchable`); the templates use 13 of 32 actions, 8 of 11
  domains, 6 render types. Facts that change the picture: sprite `size` is a **half-extent**, `add` is
  `glBlendFunc(ONE, ONE)`, `rotation`/`angular_vel`/`starting_age` are Gaussian **(mean, σ)** pairs, the
  authored `sprite_axis_align_*` type is **unknown to the original's parser** and drawn as a plain
  billboard, `damping` is `v *= 1 − dt·(1 − d)` with authored negative `d`. Today `"Effect"` (735
  placements) is a bare `VisualEntity`, `"ParticleSystem"` (42) maps names to five presets, and the Lua
  effect API is stubbed (33.11). Ten subphases 46.0–46.9 (harness, parser, PAPI core, renderer,
  instance/coordinator, entity class, script API, engine channels incl. material pairs by contact
  speed, `object_flare` lens flares, closing). Part B is the path to a **modern system** (Phase 51
  sketch; numbered 47 until the 2026-09-21 roadmap): a `.yaefx` JSON schema, one runtime with the legacy interpreter as a converter (faithful by
  default, "recipe vs lock" as in `yae-materials`), GPU path, `RenderScene` batches; Effekseer assessed
  and accepted by the user as an editor/import (as-is or a fork), not as the core runtime; the visual
  editor is a separate phase (yae-sdk or Workbench). **Resource policy (user, 2026-09-18):** the pilot
  (release 1) runs on the original resources only; from the second version on (Phase 51+, effects v2) total
  modification is allowed — new formats, new versions of old formats — **with compatibility** kept.
- `yae-engine/docs/Roadmap.md` — **the order of the phases after 46** (approved 2026-09-21): the
  user's retail session first in time (`RetailSession.md` — every question, recording and decision
  that only the user can settle), then **47 Release 1 readiness** (engineering TODOs, saves, the
  campaign acceptance 38.5, `release` preset + a mid-range card, **Windows with assets last**),
  **48 material calibration on the engine side** (MC-0/1/2 of `yae-materials/docs/MaterialCalibration.md`
  — small, unblocks that repository), **49 audit and refactoring** (the proof is the gate at 0.000),
  **50 cleaning** (git history purge, licences, root layout, code and docs for publication),
  then **40.3–40.7** and **51 effects v2** (the Part B sketch of Phase 46, numbered 47 until then).
- `yae-engine/docs/RetailSession.md` — the checklist for the user's retail sessions: A recordings
  (Appendix A, the four scenes' originals, flares, fog, ropes), B behaviour questions (wheel order,
  flare show/hide, anchors, prop contacts, hidden idles, `AreaHide`), C items the user deferred,
  D decisions (`r_fx_lights`, `pl_sprint`, colour profile, licences, the case-variant EDF tree on
  NTFS, gor's zeppelin, publication timing, Effekseer) and how answers flow back into TODO/Invariants.
- `yae-engine/docs/Phase47_Release1Readiness.md` — **the current tracker** (plan 2026-09-23;
  **47.0 done** — the Release 1 criteria K1–K7 measured on HEAD: all 12 untried campaign junctions
  load by `map` with 0 errors, 12 of 16 slots clean under ASan (our four `meat` slots 43–46 NaN),
  `release` smoke 25/25, `med1` runs under wine for the first time; retail answers closed in
  `TODO.md`; **47.1 done** — every DS2 angle is horizontal at the frame's own aspect
  (`gameplay::ds2Projection`, `Camera::fov` holds it as authored), the hands are `m_model_fov` at the
  weapon's authored 4:3 with no camera offset; `reference_scenes.sh --retail` measures the five
  `slot-*` scenes against their retail frames with `scripts/fov_match.py` — far pairs 1.00 ± 0.005; **47.2 done** — an effect's `light_desc` with `duration > 0` is a fading point light beside
  the lamps (`r_fx_lights`, on — D1, beyond retail), at the level's mean lamp intensity; a level
  without lamps now clears the light buffer instead of keeping the previous level's lamps; **47.3
  done** — the authored `damage` command deals `hit`, or twice the health with `kill` (RE
  `FUN_0f82dfc0`), and a blast hurts every hitbox it reaches, the missile's shooter too (RE `0f8cd2f0`);
  the blast on the player — one capsule here, per-bone geoms in retail — is deferred in `TODO.md`;
  **47.4 done** — engineering TODOs 5–13: a physical door is held at its stop by its motor instead
  of being teleported; a model's `.phs` is found by name under `models/` (`physics/PhsLocator.h`,
  `FS_PATH_MODELS` — met6's belts, `klumba`), and a prop's ball blank on all three axes is a weld;
  NPC move sounds are the script's alone; a callback's table arrives as a luaobject (NPC reload);
  a prop's contact plays its material's `inter_info` `coll_*` (a reconstruction, sound only as in
  retail B7); `FlySpeed` 100 re-verified and left as a retail question (B12); **47.5 done** — the
  user's saves: the player's slope limit is 50° like an NPC's (the campaign's steel stairs bevel
  every nosing at exactly 45°, a float tie at a 45° limit — Save 45 on `meat`), and `ai_activate`
  hands the activator (`game/EnemySeed.h` — kolhoz_part2's born-enabled madman had run to his cliff
  anchor at load; since the 47.6 follow-up **nobody** is seeded with the player at load, as in the
  original — the dormant seed also primed perception, so a bare `enable` woke kolhoz_part2's yard of
  fake-dead kolkhozniks all at once instead of the authored one-by-one `ai_activate`s);
  **47.6 done** — saves: format 5 carries each prop's clip (`animBlock`; a platform's bones and every
  lift body are teleported onto it) and each FSM's update schedule, nine classes write their own state
  (button, counter, timer, lift, conveyor, joint, bomb, WorldProps, barrier — appended at the end of a
  leaf class, read only when present), a load no longer runs `on_level_start` (the original's `+0xf6`
  restore flag), console `physics nan`; the 16 slots load clean under ASan except our pre-format-5
  `meat` 43–46, which need re-saving; follow-ups the same day: an NPC's own `fire_trace` is scaled by
  `g_diff_levels` and a random half, and an imported retail save brings the player's inventory — the
  records' class HUID is the prototype's `guid` (`game/ScriptClassTable.h` reads `prototypes`), the
  bag is the player's native block, `SaveFormat.md`); **47.7a done 2026-09-27/28** — the user's
  playthrough: moto shown, AI hears steps/shots and no longer runs into walls, the guard survives a
  load, stuck missiles hurt, death effects let go, swim 275, rifle clip planes, particle `tex_env`
  clamped, fallback lamps per level; the ZIL (10) has two roots and waits for a retail recording;
  **47.8 done** — `release` shoots 25/25 against the `dev` baselines (≤ 0.002/255), all presets free of
  warnings, the frame budget measured on this machine (the mid-range card is the user's);
  **47.9 done** — levels and maps from the paks (`resource/Vfs.h`, see Build & run), which found an
  unrecorded ×10 impulse edit in the unpacked `med1/medC`; **47.10 done under wine** — self-tests
  260/260 and 223/223, 25 levels, `med1`'s gate frame pixel-identical, saves on a Windows path;
  **K2 measured** — `scripts/save_roundtrips.sh` (three save/load round trips per level under ASan,
  bounded) found and fixed a door's non-unit rotation after a load and same-named twins paired
  crosswise (`Save pairs twins`); **47.12 done** — the user's three decisions: `medC` restored in the
  tree (the audit's ACCEPTED list is empty), every pak but the sounds mounted with the original's
  newer-copy-wins rule (a Steam install runs; a newer loose file is a mod), and a prop's mass from its
  `.phs` (the ZIL 3 400, not 30 000; med1's `mosk401door` a 1 900-kg car) — the ZIL scene's end waits
  for the retail recording; plan: 47.0 criteria → 47.1 retail-slot scenes (D9) + FOV by the real aspect (the
  authored DS2 horizontal FOV — `view_fov` 90, weapons 90/55/45 — goes through a fixed 4:3 in
  `ds2FovToVerticalDeg`, so 16:9 is 1.333× too wide) → 47.2 `light_desc` flash → 47.3 the
  `damage` command and the electrobolt against retail numbers → 47.4 engineering TODOs → 47.5
  the user's saves (stairs, kolhoz_part2 scene) → 47.6 save state (9 of 29 entity classes write
  their own) → 47.7 the campaign by name (12 untested stitches) → 47.8 `release` + mid-range card
  → 47.9 levels from the paks (D5) → 47.10 Windows with assets → 47.11 Release 1 candidate.
- `yae-engine/docs/Phase47_UserChecklist.md` — what the user has to do, check in our game, compare
  with retail and decide after 47.0–47.10 (re-save the format-4 slots 43–48, retail questions, pending
  decisions, re-recorded baselines to eyeball; section 7: the ZIL recording, restoring `medC`, mounting
  the remaining paks for a Steam install, the mid-range card, `windows.yml`); answers flow back as
  `RetailSession.md`'s do.
- `yae-engine/docs/Phase48_MaterialCalibrationEngine.md` — **the current phase** (plan 2026-09-28;
  **48.0 and 48.1 done 2026-09-29** — 48.1 is `MaterialContract.md` (above); 48.0: baseline on the isolated root — `--check`, gate 25/25 and scenes 9/9 at
  0.000, the crane unchanged; the ward floor named by painting stems with a solid-colour catalog
  (`scripts/paint_catalog.py` + `debug_view albedo`): `plitkaromb` (`cubeman`) under the camera,
  `plitkashahmatorez` 0 px in the frame (it is the corridor's side fields beside `plitkashahmatbit`),
  and `cubeman` does not bypass the catalog's base colour; the ward wall's real lightmap is 0.16 (the
  rig's 0.5 is 3× that); med1's opening `fade_out_long` makes the `ward` frame at 240 frames 80 % bright
  (numbers from it, debug views too, are ×0.8 — slot scenes are not affected); `--retail` prints the
  light per slot scene (`scripts/exposure_match.py`): without our composite shop/tunnel/yard are within
  3–15 % of retail, lastzlo 0.68 ≈ 1/1.5; found and fixed on the way: the GL self-test `Grey card`
  failing since `4471ebe` — a C++ `#include` pasted into its GLSL; M–L; runs **in parallel with the user's Phase 47 testing** — every picture change behind a
  cvar that stays off until one joint switch in 48.10, engine runs on an isolated root with a copied
  `config/`, 47 and 48 in separate commits): it also takes **40.1b** (the frame as retail shows it: the
  same baked lightmaps, output without our exposure 0.7 + Reinhard — the original has no tonemapper,
  and that composite halves mid-tones: 4 of 5 slot scenes are 1.6–2.4× darker than retail, ×1.0–1.5
  once it is undone; `r_ll_scale` ×1.5 after `gor` (Q5), lamps double-counted over lightmaps on
  `ward`; `linear` by default) and **40.4.1** (BRDF LUT, probe, specular on lightmapped walls
  normalised by the lightmap). The engine side of the material calibration — `MaterialContract.md` (MC-0), `--matball` with
  `matball.json` beside each frame (MC-1), `debug_view tangent|bitangent`, the sign table on
  `calib-bump-l` and the V-axis hypothesis H1 decided by number (MC-2; if confirmed, relief flips on every
  catalog surface — approved), the user's target (2026-09-28): **maximum compatibility** with downloaded
  and generated materials — glTF 2.0 conventions as the base, UE's DirectX normals by the per-material tag
  (Q4: glTF/OpenGL is the default for an untagged record), relief gain default 2 (no such constant exists in UE/Unity — their
  baked light is directional; ours becomes so in 40.5.3), 40.4.1 before 40.3.1; the `cubeman` question (by `--dump`, the ward floor is
  `plitkaromb`, not `plitkashahmatorez`), C10 (a model template's own `diffuse_texture`/`color4`), and
  the handoff that unblocks `yae-materials` CAL-05+.
- `yae-engine/docs/console/` — two files: `CONSOLE_ARCHITECTURE.md` (how it is built, how to add a
  command) and `CONSOLE_COMMANDS.md`, **generated** from the registry by `bash scripts/console_reference.sh`
  (`--check` says whether it is stale). `bash scripts/stats.sh` prints the numbers README no longer stores.
- Skills `yae-codeguide` (auto-invoked when editing C++/Lua) and `yae-review` encode conventions & anti-patterns.

## Golden rules

1. **C++ = engine primitives, Lua = game logic.** Thin bindings; let Lua prototypes decide behaviour.
2. **Never modify game resources** (`.ds2*`). Compensate in code (see `physics::kCrane*` for the meat-crane case).
   Horizon (user's decision 2026-09-18, `Phase46_EffectsParticles.md`): this holds for the pilot release; from
   the second version on, improvements may modify or replace resources — new formats, new versions of the
   old ones — as long as the untouched originals keep loading.
3. **Preserve the deterministic frame order** (see Invariants.md) — reordering breaks game logic.
4. Physically-sensitive changes: verify on **m02/meat** (crane/joints/ropes) — see LevelTestMatrix.md.

# Project Empty workspace — guide

The workspace of Project Empty: *You Are Empty* (2006) restored as an open ecosystem. This directory is a
clone of `OpenYAE/project-empty` (the ecosystem README, `bootstrap.sh`, this guide); `bootstrap.sh` clones the
other repositories beside each other in it. Each one is its own git repository with its own gate.
**Game resources are treated as read-only** — never modify `.ds2*` asset files.

## Layout

- `yae-engine/` — the engine (C++20, SDL3, OpenGL 4.5, Jolt, Lua 5.4) with its gates, scripts, build entry
  points and agent skills. **Its commands run from `yae-engine/`** (`bash build.sh --check`,
  `bash scripts/…`); its guide is `yae-engine/CLAUDE.md`, imported below.
- `yae-game/` — your copy of the game, in no repository: `gameres/` (the assets, **read-only**),
  `documents_my games/YaE/` (what the original writes to *My Documents* — **read-only reference**),
  `my games/` (writable), `ds2base.cfg`.
- `yae-sdk/` — the SDK: level editor, format library, converters (gate: `quality-gate`).
- `yae-materials/` — the community PBR material catalog (gate: `npm run validate`).
- `yae-viewer/` — the browser viewer; `yae-docs/` — the documentation portal; `yae-research/` — the public
  notes on the original DS2 Engine.
- `yae-research-private/` — the private RE repository (the decompiled originals the engine's docs cite,
  the Ghidra project): only on the maintainer's desk, never published.
- `yae-level-converter/`, `yae-dcc-plugins/`, `yae-QindieGL/`, `yae-dlss5/` — tools for the original game.

The map of the repositories and what each one is for: `README.md`.

@yae-engine/CLAUDE.md

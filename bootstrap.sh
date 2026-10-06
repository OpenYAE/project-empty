#!/usr/bin/env bash
# Project Empty — make this clone a working workspace (Phase 50.4, D32).
#
# This repository is the workspace's root: the ecosystem's README and the
# agents' CLAUDE.md. bootstrap.sh clones the other repositories into it, under
# the names the engine's scripts expect beside the engine (since Phase 50.6 the
# engine holds its own gates: build.sh, scripts/, render.cfg), and checks the
# layout. It is idempotent: an existing clone is pulled, not
# cloned again. Your copy of the game goes into ./yae-game by hand.
#
#   git clone https://github.com/OpenYAE/project-empty && cd project-empty
#   bash bootstrap.sh [--ssh] [--all] [--base <url or directory>]
#
# --ssh    git@github.com: URLs instead of https
# --all    also the repositories outside Release 1: yae-QindieGL,
#          yae-dcc-plugins, yae-level-converter, yae-dlss5
# --base   where the repositories live: a URL prefix, or a directory holding
#          <name>/ clones (a mirror, or a test of this script)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

ORG="${OPENYAE_ORG:-OpenYAE}"
BASE="https://github.com/$ORG"
ALL=0
while (($#)); do
    case "$1" in
        --ssh) BASE="git@github.com:$ORG"; shift ;;
        --all) ALL=1; shift ;;
        --base) BASE="${2:?--base needs a URL or a directory}"; shift 2 ;;
        *) echo "bootstrap.sh: unknown option $1" >&2; exit 2 ;;
    esac
done

# Release 1 (D31), then the rest. yae-sdk's gate scripts are read from
# yae-sdk/sdk-desktop, the material catalog from yae-materials/export.
CORE=(yae-engine yae-sdk yae-materials yae-docs yae-research yae-viewer)
EXTRA=(yae-QindieGL yae-dcc-plugins yae-level-converter yae-dlss5)

source_of() {
    local name="$1"
    if [[ -d "$BASE" ]]; then
        if [[ -d "$BASE/$name.git" ]]; then echo "$BASE/$name.git"; else echo "$BASE/$name"; fi
    else
        echo "$BASE/$name.git"
    fi
}

failed=()
clone() {
    local name="$1"
    if [[ -d "$name/.git" ]]; then
        echo "== $name: pull"
        git -C "$name" pull --ff-only || echo "   ($name: pull skipped — local changes or a detached head)"
    else
        echo "== $name: clone"
        git clone --recurse-submodules "$(source_of "$name")" "$name" || failed+=("$name")
    fi
}
for r in "${CORE[@]}"; do clone "$r"; done
if ((ALL)); then for r in "${EXTRA[@]}"; do clone "$r"; done; fi

echo
echo "Layout:"
ok=1
for r in "${CORE[@]}"; do
    if [[ -d "$r/.git" ]]; then echo "  [x] $r"; else echo "  [ ] $r — not cloned"; ok=0; fi
done
if [[ -d yae-game/gameres ]]; then
    echo "  [x] yae-game/gameres — your copy of the game"
else
    echo "  [ ] yae-game/gameres — copy your You Are Empty here (the folder that holds gameres/);"
    echo "      the engine builds without it, the level gates SKIP"
fi
((${#failed[@]})) && echo "Not cloned: ${failed[*]} (no access, or not published yet)."
echo
echo "Next (the engine's commands run from yae-engine/):"
echo "  (cd yae-sdk/sdk-desktop && npm install)   # the SDK's parsers, for the conformance gate"
echo "  cd yae-engine"
echo "  bash build.sh                  # the engine, dev preset, with its self-tests"
echo "  bash run_level.sh -map med1    # a level of the game (needs ../yae-game/)"
echo "  bash build.sh --check          # every gate, before a commit"
((ok)) || exit 1

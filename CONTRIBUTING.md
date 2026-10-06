# Contributing to Project Empty

This file is the ecosystem's contribution guide; every repository's README links here and adds only
what is specific to it (its gate command, its layout).

## Two rules that never bend

1. **No game assets.** Levels, models, textures, sounds, scripts and binaries of *You Are Empty*
   belong to their rights holders. Nothing from `gameres` or the game's install is committed,
   attached to an issue, or pasted into a pull request beyond a short quote needed to explain a
   defect. Tests that need an asset look for it in the contributor's own copy of the game and
   report SKIP when it is absent.
2. **No decompiled code.** Reverse-engineering findings are published as descriptions: names,
   offsets, addresses, layouts, behaviour. A decompiler listing does not enter a public repository,
   not even as a comment. Cite evidence the way the engine does — `FUN_0f8a7940` for an address in
   the original binary, `+0xa34` for a field offset — so that anyone with the game and a disassembler
   can check it.

## Language

The working language is English: code, comments, commit messages, issues, pull requests, contracts
and specifications. Translations of READMEs and guides into Russian and Ukrainian are welcome as
`<name>.ru.md` / `<name>.uk.md` next to the English file; the documentation portal shows them
under its language switcher. A quoted string from the game stays in its own language with an
English gloss. Details: the portal's *Languages* page.

## How the projects work

- **Measure before you fix.** The engine's phase documents record, for every defect, the root that
  was read in the data or the original's behaviour, the hypotheses that were ruled out, and the
  self-test or gate that keeps it fixed. A pull request that changes behaviour says which of the
  golden levels it was checked on and how.
- **The gate runs before a commit.** Engine: `bash build.sh --check` in `yae-engine/` (warnings,
  self-tests, size budgets, the `gameres` audit, the console reference, parser conformance with the
  SDK, formatting of changed lines, the 24-level smoke pass). SDK: `cd sdk-desktop && npm run
  quality-gate`. Catalog: `npm test && npm run validate`. Portal: `npm run build`.
- **Contracts live in one place.** The engine's `Invariants.md` states what must not be broken and
  names the self-test that guards each section; the cross-project conventions (units, coordinate
  systems, colour, assets) live in the portal. A change that contradicts one of them is a change of
  the contract first, with the reason written down.
- **Original data is read-only.** The engine compensates for defects of the original scripts in
  code until the first stable release; `OriginalScriptDefects.md` lists them.

## Bug reports

A good report names the repository and commit, the level or file, what you did (console commands,
save slot, coordinates from `pos`), what you expected, what happened, and attaches the log
(`yae-engine.log` for the engine). A screenshot or a short clip helps for anything visual. Reports
about the re-release's assets say so: the *Absolute Edition* and the 2006 release are different
builds.

## Pull requests

- One change per pull request, with the gate green and the reason in the description.
- New behaviour comes with a self-test (engine), a unit or round-trip test (SDK) or a fixture
  (catalog); a fixed defect comes with the test that would have caught it.
- Follow the repository's style tool (`.clang-format` in the engine, ESLint/Prettier in the SDK);
  the gates check only the lines you changed.
- Sign your commits off (`git commit -s`) to certify the
  [Developer Certificate of Origin](https://developercertificate.org/); there is no contributor
  license agreement.

## Working with AI agents

Most of Project Empty was written by AI agents (Claude and Codex) under the maintainer's direction,
and contributions made with an agent are welcome on the same terms as any other: the gate green,
the measurement in the description, a test for new behaviour. The `CLAUDE.md` of the workspace and
of the engine, and the engine's agent skills, describe the layout, the gates and the conventions for
agents and people alike. Whoever
opens the pull request answers for it — the sign-off above is theirs — and an agent must not be
given game files or decompiled code to put into a commit, any more than a person.

## Where to talk

Issues and discussions in the repository the topic belongs to; cross-project questions in the
`project-empty` repository. Be concrete, be kind, and assume the other person has read less of
the code than you have.

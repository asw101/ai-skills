# Skills Consolidation Plan

Consolidate the 8 skills on `main` into 6 once the `component-cli` skill (branch
`claude/rename-wasm-cli-0Uk8v`) is merged. The new `component-cli` covers
`init / install / run / compose / registry / local / self`, which makes
`wasm-cli`, `wasm-registry`, and `wasm-search` largely redundant.

## Problem

- `wasm-cli` (old) overlaps minimally with `component-cli` (new) and is being
  replaced by an upstream rename (`yoshuawuyts/wasm-cli` → `…/component-cli`).
- `wasm-registry`'s OCI ops (`wkg oci pull|push`) are a strict subset of
  `component registry pull|push|inspect|tags|search|sync|known|list|delete`.
- `wasm-search`'s discovery story (curated `components.json` + `wkg pull`) is
  superseded by `component registry search`, with the static catalog only
  useful as an offline fallback when no meta-registry is reachable.
- `wasm-run` still has unique value: `--invoke` with WAVE syntax for library
  components, AOT `compile`, `wizer`, WASIp3 flags, `objdump`, `explore`,
  fine-grained WASI permissions.
- `wasm-build` is unaffected (`component-cli` does not compile from source).
- `wasm-wassette`, `just`, `hyperlight-sandbox` are orthogonal.

## Target topology (6 skills)

| Skill | Status |
|---|---|
| `component-cli` | merged from branch; absorbs registry + search material |
| `wasm-run` | trimmed to wasmtime-unique features |
| `wasm-build` | minor edits; defer compose CLI invocation to `component-cli` |
| `wasm-wassette` | unchanged |
| `just` | unchanged |
| `hyperlight-sandbox` | unchanged |

Removed: `wasm-cli` (renamed), `wasm-registry` (folded), `wasm-search` (folded).

## Approach

Land in **four phases**, each independently reviewable:

1. **Merge the rename.** Bring in `claude/rename-wasm-cli-0Uk8v`.
2. **Fold `wasm-registry` into `component-cli`.** Migrate auth/annotation
   guidance to a cookbook; keep `wkg`-specific WIT-package authoring out
   (move it to `wasm-build/scripts/wkg.md`).
3. **Fold `wasm-search` into `component-cli`.** Move `components.json` to a
   `known-components.json` fallback; add a `discovery.md` cookbook.
4. **Trim `wasm-run` and `wasm-build`.** Remove duplication with
   `component-cli`; cross-link.

A final **phase 5** updates the repo-level docs and Justfile to match
the new topology.

## Phased todos

### Phase 1 — merge the rename branch
- **p1.merge-component-cli** — Merge `claude/rename-wasm-cli-0Uk8v` into
  `main`. Verify `.agents/skills/component-cli/SKILL.md` lands and the old
  `.agents/skills/wasm-cli/` directory is removed. Update `.gitignore` so
  the binary path becomes `.agents/skills/component-cli/scripts/component`.

### Phase 2 — fold `wasm-registry` into `component-cli`
- **p2.extract-registry-auth-cookbook** — Create
  `.agents/skills/component-cli/scripts/registry-auth.md` with the GHCR PAT
  scopes, `WKG_OCI_USERNAME`/`WKG_OCI_PASSWORD`, Docker credential helpers,
  and recommended `org.opencontainers.image.*` annotations from
  `wasm-registry/SKILL.md`.
- **p2.link-registry-auth-from-component-cli** — Add a "Registry
  authentication & annotations" section to `component-cli/SKILL.md`
  pointing at the new cookbook, and mention it in the `registry push`
  workflow.
- **p2.move-wkg-wit-to-wasm-build** — Move WIT-package authoring guidance
  (`wkg wit build`, `wkg publish`, lockfile semantics) from
  `wasm-registry` and `wasm-build/scripts/wkg.md` into a single canonical
  location under `wasm-build/scripts/wkg.md`.
- **p2.delete-wasm-registry** — `git rm -r .agents/skills/wasm-registry/`.
  Search the repo for any remaining references (Justfile, docs) and
  redirect them.

### Phase 3 — fold `wasm-search` into `component-cli`
- **p3.move-components-json** — Move `wasm-search/components.json` to
  `component-cli/scripts/known-components.json`. Update `version`,
  `last_updated`, refresh the WASI 0.3-RC wording, and fix the
  `qr-code-webassembly` placeholder entry (or drop it).
- **p3.create-discovery-cookbook** — Add
  `component-cli/scripts/discovery.md`: `component registry search`
  first; offline fallback to `known-components.json`; WebFetch
  `awesome-wasm-components` README for live lookups.
- **p3.update-component-cli-skill** — Add a "Discovering components"
  section to `component-cli/SKILL.md` linking the new cookbook. Move the
  `WebFetch` allowed-tool in (currently only `Bash, Read, Write, Edit,
  Glob, Grep`).
- **p3.delete-wasm-search** — `git rm -r .agents/skills/wasm-search/`.
  Search the repo (Justfile `get-wkg`, `get-wasm-tools`, `clean-binaries`)
  for references and redirect: relocate the `wkg` and `wasm-tools`
  binaries either to `component-cli/scripts/` (if still wanted) or to a
  shared `.agents/bin/` directory.

### Phase 4 — trim `wasm-run` and `wasm-build`
- **p4.trim-wasm-run** — Remove duplication with `component-cli`:
  delete the basic "run an OCI ref" examples; collapse the simple
  `--dir`/`--env` examples; keep and emphasize `--invoke` (WAVE),
  `serve --addr` advanced use, `compile`, `wizer`, `objdump`, `explore`,
  `settings`, WASIp3 (`-Sp3 -Wcomponent-model-async`), debug/profile.
  Reframe description: "wasmtime-specific runtime features for
  components."
- **p4.cross-link-component-cli-from-wasm-run** — At the top of
  `wasm-run/SKILL.md`, add a note: "for OCI ref / manifest-key execution,
  use `component-cli`."
- **p4.update-wasm-build-composition** — In
  `wasm-build/scripts/composition.md`, defer CLI invocation to
  `component compose` (referencing `component-cli`); keep WAC-script
  syntax and `--linker static|dynamic` semantics.
- **p4.update-wasm-build-related-skills** — In `wasm-build/SKILL.md`
  "Related skills" section, replace `wasm-cli` with `component-cli`,
  remove `wasm-registry` and `wasm-search`, update language.

### Phase 5 — repo docs & Justfile
- **p5.update-root-readme** — Replace the empty `README.md` with a brief
  orientation + 6-skill table.
- **p5.update-skills-overview** — Rewrite `docs/skills-overview.md` to
  list all 6 skills (currently lists 5; missed
  `hyperlight-sandbox`/`wasm-cli`/`wasm-wassette`).
- **p5.update-agent-skills-doc** — Update `docs/agent-skills.md` table
  to match (6 rows).
- **p5.update-allowed-tools-doc** — Update `docs/allowed-tools.md` to
  list 6 skills with their actual `allowed-tools` frontmatter (current
  doc is stale: missed `WebFetch` on `wasm-build`/`wasm-search`, and
  missed three skills entirely).
- **p5.update-justfile** — Rename Justfile recipe `get-wasm-cli` →
  `get-component-cli`; binary destination
  `.agents/skills/component-cli/scripts/component`; update
  `clean-binaries` and `get-all`. Decide whether `get-wkg` /
  `get-wasm-tools` survive (likely yes for `wasm-build`, relocated to
  `wasm-build/scripts/` or a shared bin dir).
- **p5.fix-stale-references** — Grep for remaining mentions of
  `wasm-cli`, `wasm-registry`, `wasm-search`, and the dangling
  `wasm-oci` reference in
  `wasm-registry/scripts/README.md` (now removed in p2).
- **p5.refresh-dates** — Bump `Last verified` / `last_updated` strings
  in surviving files.

## Risks & open questions

- **`wasm-tools` and `wkg` binary location.** Both are referenced from
  multiple skills. After Phase 3 the dedicated `wasm-search/scripts/`
  home is gone. Options: (a) put them in `component-cli/scripts/`;
  (b) put them in `wasm-build/scripts/`; (c) introduce a shared
  `.agents/bin/` and update each SKILL.md's binary-detection snippet.
  Decide before Phase 3.
- **`wkg wit build` / `wkg publish`.** `component-cli` cannot publish
  raw WIT packages today; only built `.wasm` components. If the repo
  needs a WIT-package publishing flow, keep that material under
  `wasm-build/scripts/wkg.md`. Confirm with maintainer.
- **`component-cli` cannot `--invoke` library exports.** This is the
  main reason `wasm-run` survives. If upstream adds WAVE-style invoke,
  revisit whether `wasm-run` collapses into `component-cli` too.
- **Meta-registry availability.** `component registry search/sync/known`
  require a running meta-registry (`localhost:8080`). The `discovery.md`
  cookbook must clearly explain the no-meta-registry path, otherwise
  agents will hit confusing errors.
- **OCI annotation conventions.** `component registry push` does not
  document a way to set `org.opencontainers.image.*` annotations from
  the manifest. Verify before declaring `wasm-registry` fully redundant
  — if not supported, either keep `wkg`-based publish as a fallback in
  the new cookbook, or file an upstream issue.
- **The branch's expanded SKILL.md is heavy** (~310 lines, 15.5 KB).
  Consider splitting `component-cli/SKILL.md` into a slim core +
  per-subcommand cookbooks (`run.md`, `compose.md`, `registry.md`)
  before Phase 2 starts adding more material to it.
- **Branch name vs. upstream name.** The branch is
  `claude/rename-wasm-cli-0Uk8v`. Confirm whether to rebase, merge as-is,
  or open a PR with a cleaner branch name before merging.

## Execution order

`p1.*` → `p2.*` → `p3.*` → `p4.*` → `p5.*`. Phases are sequential because
later phases reference structure created in earlier ones. Within a phase,
tasks can run in parallel.

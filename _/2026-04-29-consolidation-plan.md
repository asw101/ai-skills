# Skills Consolidation Plan

Maintain **two parallel skill stacks** for WebAssembly component work:

1. **`component`** (default) — `yoshuawuyts/component-registry`'s `component`
   tool for the full lifecycle: `init / install / run / compose / registry /
   local / self`.
2. **`wasm-toolchain`** + **`wasmtime`** (explicit) — the upstream Bytecode
   Alliance tools (`wasm-tools`, `wkg`, `wasmtime` CLI), surfaced when the
   agent or user explicitly asks for them, or when `component` can't do the
   job.

Earlier drafts of this plan deleted `wasm-registry` and `wasm-search` by
folding them into `component`. The current plan keeps the BA functionality
intact in a renamed/consolidated skill set, deferring to `component` only
where it's clearly the better fit.

## Skill routing model

```
USER REQUEST
    │
    ├─ explicitly names "wkg" / "wasm-tools" / curated catalog ──▶ wasm-toolchain
    ├─ explicitly names "wasmtime"                              ──▶ wasmtime
    ├─ wants --invoke WAVE / compile / wizer / objdump / WASIp3 ──▶ wasmtime
    ├─ wants WIT-package authoring / OCI annotations / GHCR PAT ──▶ wasm-toolchain
    ├─ wants per-language compilation                            ──▶ wasm-build
    ├─ everything else WebAssembly-component-related (default)   ──▶ component
    └─ orthogonal                                                ──▶ just / hyperlight-sandbox
```

The default routing is encoded in **SKILL.md `description:` fields**: each BA
skill description starts with "Use when explicitly requested or when
`component` cannot..." while `component`'s description signals it as the
default.

## Target topology (7 skills)

| Skill | Status | Role |
|---|---|---|
| `component` | ✅ merged | **Default** for component lifecycle (init / install / run / compose / registry / local / self) |
| `wasm-toolchain` | **new** (combine `wasm-registry` + `wasm-search`) | BA registry & inspection: `wkg` (OCI push/pull, WIT-package authoring, GHCR auth, annotations) + `wasm-tools` (validate, inspect, embed, component new/extract) + curated `components.json` catalog |
| `wasmtime` | **rename** (`wasm-run` → `wasmtime`) | wasmtime-specific runtime: `--invoke` WAVE, AOT `compile`, `wizer`, `objdump`, `explore`, `settings`, WASIp3 (`-Sp3 -Wcomponent-model-async`), fine-grained WASI permissions |
| `wasm-build` | minor edits | Per-language compilation (Rust, Python, JS, Go/TinyGo). Defers `compose` invocation to `component`; cross-links `wasm-toolchain/scripts/wkg.md` for WIT-package fetch. |
| `wasm-wassette` | unchanged | |
| `just` | unchanged | |
| `hyperlight-sandbox` | unchanged | |

Removed: `wasm-cli` (already renamed to `component` in P1),
`wasm-registry` (folded into `wasm-toolchain`), `wasm-search` (folded into
`wasm-toolchain`).

## What survives from `wasm-search`

The skill itself is replaced. Two assets carry forward into `wasm-toolchain`:

| Asset | Destination | Notes |
|---|---|---|
| Curated catalog (was `components.json`, ~354 lines / 14.9 KB JSON) | `wasm-toolchain/scripts/components.md` (markdown table, ~40 lines) | Three columns: OCI ref / Language / Description. ~26 rows. Drop the per-entry `use_cases`, `interfaces`, `notes`, `github`, `wasi_version`, `local_path` and the top-level `metadata` block. Drop the `qr-code-webassembly` placeholder. |
| Discovery-by-task workflow | `wasm-toolchain/scripts/discovery.md` (new cookbook) | WebFetch awesome-wasm-components → fall back to `components.md` → `wkg oci pull` → cross-link to `component registry search` for the meta-registry future. |

Deprecation path: when `component registry search` against a real meta-registry
is reliable, `components.md` gets deleted in one `git rm` and `discovery.md`
loses one paragraph. Until then, the markdown table is the offline fallback.

Dropped: the `wasm-search` SKILL.md prose duplicates `wkg oci pull` and "Local
component registry maintenance" guidance — both live in `wasm-toolchain`.

`component/SKILL.md` gets a one-paragraph mention: "For component
discovery: `component registry search` (needs a running meta-registry); offline
fallback at `wasm-toolchain/scripts/discovery.md`."

## Approach

Land in **four phases** after the already-done P1 (component-cli merge):

- **P2**: Restructure — create `wasm-toolchain`, rename `wasm-run` → `wasmtime`, delete the obsolete folders.
- **P3**: Description routing — make every SKILL.md frontmatter explicit about default vs. explicit invocation (one pass).
- **P4**: Trim and cross-link — remove duplication, defer to `component` where appropriate but keep functionality. Add an overlap matrix to docs.
- **P5**: Repo docs & Justfile — root README, skills-overview, agent-skills, allowed-tools, Justfile recipes, dates.

## Phased todos

### Phase 1 — merge the rename branch ✅

- **p1.merge-component-cli** ✅ done

### Phase 2 — restructure existing skills

- **p2.create-wasm-toolchain** — Create `.agents/skills/wasm-toolchain/`
  with a slim SKILL.md (target ≤ 250 lines) + three cookbooks:
  - `scripts/wkg.md` — OCI pull/push with full annotation control
    (`org.opencontainers.image.*`), GHCR PAT scopes,
    `WKG_OCI_USERNAME`/`WKG_OCI_PASSWORD`, Docker credential helpers, and
    WIT-package authoring (`wkg wit build`, `wkg publish`, lockfiles).
  - `scripts/wasm-tools.md` — `validate`, `inspect`, `print`,
    `component embed/new/extract`, `metadata add`, etc.
  - `scripts/discovery.md` — discovery-by-task workflow.
  - `scripts/components.md` — curated catalog as a markdown table
    (3 cols: OCI ref / Language / Description; ~26 rows; ~40 lines).
    Replaces the legacy `wasm-search/components.json`. Deletable in one
    `git rm` once meta-registries are reliable.
  - `allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebFetch`.
- **p2.rename-wasm-run-to-wasmtime** — `git mv .agents/skills/wasm-run/
  .agents/skills/wasmtime/`. Update SKILL.md frontmatter (`name: wasmtime`),
  any heading text, and the `.gitignore` line for the wasmtime binary path.
- **p2.delete-old-skills** — `git rm -r .agents/skills/wasm-registry/
  .agents/skills/wasm-search/` once content is migrated. Sweep the repo
  for references; redirect to `wasm-toolchain` paths.

### Phase 3 — description routing (one pass)

- **p3.update-skill-descriptions** — In a single pass, rewrite the
  frontmatter `description:` of all 7 skills to encode default-vs-explicit
  routing:
  - `component`: "Default for component lifecycle... Use first unless
    user explicitly names `wasm-tools`, `wkg`, or `wasmtime`, or
    `component` cannot do the job."
  - `wasm-toolchain`: "Use when user explicitly names `wkg`,
    `wasm-tools`, or asks for raw OCI annotations / WIT-package authoring
    / curated component discovery without `component`. Otherwise prefer
    `component`."
  - `wasmtime`: "Use when user explicitly names `wasmtime`, or needs
    runtime features `component run` doesn't expose: `--invoke` WAVE, AOT
    `compile`, `wizer`, `objdump`, `explore`, `settings`, WASIp3.
    Otherwise prefer `component`."
  - `wasm-build`, `wasm-wassette`, `just`, `hyperlight-sandbox`: minor
    cross-reference touches; replace any `wasm-cli` / `wasm-registry` /
    `wasm-search` / `wasm-run` mentions in descriptions with the new
    skill names.

### Phase 4 — trim and cross-link

- **p4.trim-overlap** — In one pass across `component`, `wasmtime`,
  and `wasm-toolchain` SKILL.mds, remove duplication and add cross-links:
  - `component`: cross-link `wasmtime` for WAVE invoke and
    `wasm-toolchain/scripts/wkg.md` for raw OCI annotations. If
    `component/SKILL.md` is still > 250 lines after this pass, split
    into per-subcommand cookbooks.
  - `wasmtime`: drop basic OCI-ref-execution examples (defer to
    `component`); keep `--invoke`, `compile`, `wizer`, `objdump`,
    `explore`, `settings`, WASIp3, profiling. Top of file: "for OCI ref
    execution and component lifecycle, see `component`."
  - `wasm-toolchain`: keep flows `component` can't replicate today (full
    annotation control, raw WIT-package publish, offline curated catalog);
    cross-link `component` for the rest.
- **p4.update-wasm-build-references** — In `wasm-build/SKILL.md`
  "Related skills" section, replace `wasm-cli` → `component`,
  `wasm-registry` + `wasm-search` → `wasm-toolchain`, `wasm-run` →
  `wasmtime`. In `wasm-build/scripts/composition.md`, defer CLI
  invocation to `component compose` (cross-link `component`); keep
  WAC-script syntax and `--linker static|dynamic` semantics. Cross-link
  `wasm-toolchain/scripts/wkg.md` for WIT-package fetch.
- **p4.add-skill-routing-doc** — New file `docs/skill-routing.md` with a
  matrix: rows = tasks (init, build, run, --invoke WAVE, push, push w/
  custom annotations, pull, search registry, search curated, validate
  WIT, ...), columns = tools (`component`, `wkg`, `wasm-tools`,
  `wasmtime`), cells = recommended default + cross-link.

### Phase 5 — repo docs & Justfile

- **p5.update-repo-docs** — In one pass: replace empty `README.md` with
  a brief orientation + 7-skill table + the routing model; rewrite
  `docs/skills-overview.md` to list all 7 skills; update
  `docs/agent-skills.md` (7 rows); update `docs/allowed-tools.md` to
  reflect the actual `allowed-tools` frontmatter of all 7 skills.
- **p5.update-justfile** — Update `populate-skills` and `clean-skills`
  for the new skill folders. `wkg` + `wasm-tools` go under
  `wasm-toolchain/scripts/`; `wasmtime` under `wasmtime/scripts/`. Sweep
  recipe names and bin paths.
- **p5.cleanup-sweep** — `grep -r "wasm-cli\|wasm-registry\|wasm-search\|wasm-run"`
  across the repo, redirect each to its new skill name. Bump
  `Last verified` / `last_updated` strings in surviving files.

## Risks & open questions

- **Slash-command-style explicit invocation.** This plan relies on the
  agent's skill matcher honouring user phrasing ("use wkg to push"). If
  agents still default to `component` even when the user explicitly
  names a BA tool, the SKILL.md descriptions need to be sharpened. The
  P4 `docs/skill-routing.md` matrix gives the agent a tie-breaker.
- **Meta-registry availability.** `component registry search/sync/known`
  require a running meta-registry (`localhost:8080`). The discovery
  cookbook in `wasm-toolchain` must clearly explain the no-meta-registry
  path; cross-link to `component` for the meta-registry case.
- **OCI annotation conventions.** `component registry push` does not
  document a way to set `org.opencontainers.image.*` annotations. Until
  that lands upstream, `wasm-toolchain/scripts/wkg.md` remains the
  canonical home for annotated publishes — call this out in the routing
  matrix (P4).
- **`component/SKILL.md` is already 15.5 KB.** Split into cookbooks
  during P4 if it grows further during P3 description edits.

## Execution order

`p2.*` → `p3.*` → `p4.*` → `p5.*`. Phases are sequential; within a phase,
tasks can run in parallel.


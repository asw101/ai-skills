# `_/` — local archive

A scratch / archive folder for things that are useful to keep around
but **not part of the repo's agent context**. Session transcripts,
historical issue tickets, draft notes, working files, zip archives
of older trees — they all live here.

## Convention

`_/.gitignore` is `*` with two exceptions: this `README.md` and
`.gitignore` itself. Everything else in this folder is **ignored by
default** — running `git add .` from the repo root will never pick
up a file under `_/`.

To deliberately track something here, force-add it:

```bash
git add -f _/my-historical-doc.md
git commit -m "Archive my-historical-doc"
```

This pattern lets us:

- Keep working files alongside the repo without polluting commits.
- Archive a small set of historical documents (committed once,
  force-added) without those files being treated as living docs.
- Avoid the temptation to expand `notes/` into something readers /
  agents are expected to consult.

## Currently tracked

The files committed under `_/` are historical artifacts (old session
transcripts, retired notes, the original consolidation plan, etc.).
They are kept for provenance — agents and readers should look at
`AGENTS.md`, `README.md`, `docs/`, and `.agents/skills/<name>/SKILL.md`
for current guidance, not here.

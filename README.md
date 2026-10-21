# feature-pipeline

Spec Kit workflows: specify -> clarify (max 3 rounds) -> spec review -> plan -> tasks -> implement -> independent checks + auto-fix (max 2 attempts).

- `shared/` — scripts and prompts used by both agents
- `claude/` — Claude Code variant (`feature-pipeline`)
- `codex/` — Codex variant (`feature-pipeline-codex`)
- `dist/` — build output, not committed

## Install / update from GitHub Releases

Requires Spec Kit CLI and a project initialized with `specify init`.

```bash
specify workflow catalog add https://github.com/guensuanhoa/feature-pipeline/releases/latest/download/catalog.json --name feature-pipeline
specify workflow add feature-pipeline          # or feature-pipeline-codex
specify workflow list                          # shows installed version
specify workflow update                        # upgrade to the latest release (catalog cached 1h: rm -rf .specify/workflows/.cache)
specify workflow add feature-pipeline --from https://github.com/guensuanhoa/feature-pipeline/releases/download/v0.2.0/feature-pipeline-0.2.0.zip  # pin; update skips it
```

Migrating a `--dev` install: `specify workflow remove feature-pipeline`, then `add` from the catalog.

Release: push tag `vX.Y.Z`; `.github/workflows/release.yml` runs tests, stamps the version, uploads the zips + `catalog.json`.

## Local development

```bash
bash build.sh
specify workflow add ./feature-pipeline/dist/feature-pipeline --dev
specify workflow add ./feature-pipeline/dist/feature-pipeline-codex --dev
bash tests/run-tests.sh
```

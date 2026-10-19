# feature-pipeline

Spec Kit workflows: specify -> clarify (max 3 rounds) -> spec review -> plan -> tasks -> implement -> independent checks + auto-fix (max 2 attempts).

- `shared/` — scripts and prompts used by both agents
- `claude/` — Claude Code variant (`feature-pipeline`)
- `codex/` — Codex variant (`feature-pipeline-codex`)
- `dist/` — build output, not committed

```bash
bash build.sh
specify workflow add ./feature-pipeline/dist/feature-pipeline --dev
specify workflow add ./feature-pipeline/dist/feature-pipeline-codex --dev
bash tests/run-tests.sh
```

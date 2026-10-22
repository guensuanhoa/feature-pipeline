# feature-pipeline

Spec Kit workflows: specify -> clarify (max 3 rounds) -> spec review -> plan -> tasks -> implement -> independent checks + auto-fix (max 2 attempts).

- `shared/` — scripts and prompts used by both agents
- `claude/` — Claude Code variant (`feature-pipeline`)
- `codex/` — Codex variant (`feature-pipeline-codex`)
- `dist/` — build output, not committed

## Install / update from GitHub Releases

Requires Spec Kit CLI and a project initialized with `specify init`. Run every command from the project root (the folder with `.specify/`).

```bash
# Once per project: the catalog list lives in .specify/workflow-catalogs.yml
specify workflow catalog add https://github.com/guensuanhoa/feature-pipeline/releases/latest/download/catalog.json --name feature-pipeline

specify workflow add feature-pipeline          # Claude variant
specify workflow add feature-pipeline-codex    # Codex variant (both can be installed together)
specify workflow list                          # shows installed versions
specify workflow update                        # upgrade all catalog installs (catalog cached 1h: rm -rf .specify/workflows/.cache)
```

Pin a version instead of `add` (installs as `source=url`, so `update` skips it):

```bash
specify workflow add feature-pipeline --from https://github.com/guensuanhoa/feature-pipeline/releases/download/v0.2.0/feature-pipeline-0.2.0.zip
```

Troubleshooting:

- `All configured catalogs failed to fetch` or `CERTIFICATE_VERIFY_FAILED`: a company HTTPS proxy is in the way. Export the macOS CA bundle and point Python at it (add the `export` to `~/.zshrc`):
  ```bash
  mkdir -p ~/.config/certs
  security find-certificate -a -p /Library/Keychains/System.keychain /System/Library/Keychains/SystemRootCertificates.keychain > ~/.config/certs/macos-ca.pem
  export SSL_CERT_FILE=~/.config/certs/macos-ca.pem
  ```
- `No workflow.yml found in feature-pipeline`: the current folder has a subfolder named `feature-pipeline` (an old copied source), and Spec Kit reads the argument as that path. Delete the old copy, or run `PROJECT="$PWD"; (cd /tmp && SPECIFY_INIT_DIR="$PROJECT" specify workflow add feature-pipeline)`.
- `Not installed from a catalog — re-add to update`: the workflow was installed with `--dev` or `--from`. Migrate: `specify workflow remove <id>`, then `specify workflow add <id>`. Run `remove` only when `list` shows the id.

## Usage

Run all commands from the project root. Details and design notes for each variant: [claude/README.md](claude/README.md), [codex/README.md](codex/README.md) (also installed at `.specify/workflows/<id>/README.md`).

### 1. One-time setup per project

**Claude (`feature-pipeline`)**

```bash
claude --version    # Claude CLI installed and logged in
mkdir -p .claude
cp .specify/workflows/feature-pipeline/templates/settings.local.json.example .claude/settings.local.json
```

`settings.local.json` is the list of commands the agent may run. The template targets Go; replace the `go ...` lines with your project's build/test commands. If the file already exists, merge by hand.

**Codex (`feature-pipeline-codex`)**

```bash
npm i -g @openai/codex && codex login
specify integration install codex
specify integration use claude      # only to keep Claude as the default integration
echo 'export SPECKIT_INTEGRATION_CODEX_EXTRA_ARGS="--sandbox workspace-write"' >> ~/.zshrc
source ~/.zshrc
```

`SPECKIT_INTEGRATION_CODEX_EXTRA_ARGS` is required: without it Codex runs read-only and cannot write the spec.

**Both:** add the run files to `.gitignore` (commit `.specify/pipeline/commands.env` so the team shares it):

```
.specify/pipeline/*.log
.specify/pipeline/*.status
.specify/pipeline/current-feature
.specify/pipeline/fix-notes.md
.specify/pipeline/implement-report.md
.specify/pipeline/tasks-done.before
.specify/pipeline/clarify.log
.specify/pipeline/open-questions.md
.specify/pipeline/requirement-updated.md
```

### 2. Run a feature

```bash
specify workflow run feature-pipeline -i spec="Đọc yêu cầu trong docs/handoffs/<file>.md"
specify workflow run feature-pipeline-codex -i spec="Đọc yêu cầu trong docs/handoffs/<file>.md"
```

`spec` is a path to a requirement file or a direct feature description. Change models with `-i plan_model=... -i impl_model=...` (Claude: `opus`, `sonnet`, `haiku`; Codex also takes `-i plan_effort=...`, `-i impl_effort=...`).

The pipeline runs specify → clarify (max 3 rounds) → plan → tasks → implement → checks → auto-fix (max 2 attempts) → summary on its own.

### 3. Answer the gates

It stops and asks you only at these points:

| Gate | When | What to do | Resume input |
|---|---|---|---|
| Test commands | First run only | Check `.specify/pipeline/commands.env`, fix if wrong, approve | `commands_verdict` |
| Open questions | Still unclear after 3 clarify rounds | `continue` = accept suggestions; `important` = answer them yourself, then rerun | `questions_verdict` |
| Spec review | Always | Read `spec.md` (path printed just above), approve | `spec_verdict` |
| Checks failing | Still failing after 2 fixes | Read `.specify/pipeline/last-check.log`; approve to continue, reject to stop | `checks_verdict` |

In a terminal it asks directly. If you exited, resume:

```bash
specify workflow status                                       # find run_id
specify workflow resume <run_id> --input spec_verdict=approve
```

- Do not pass `*_verdict` to `run`: the gate passes without your review.
- Do not run both variants at the same time in one project; they share `.specify/pipeline/`.
- Hit a usage limit: the step fails but state is saved. Wait, then `specify workflow resume <run_id>`.

## Release

Push tag `vX.Y.Z`; `.github/workflows/release.yml` runs tests, stamps the version, uploads the zips + `catalog.json`.

## Local development

```bash
bash build.sh
specify workflow add ./feature-pipeline/dist/feature-pipeline --dev
specify workflow add ./feature-pipeline/dist/feature-pipeline-codex --dev
bash tests/run-tests.sh
```

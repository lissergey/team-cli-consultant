---
name: setting-up-cli-consultants
description: Use when the user wants to install or replicate the Codex (and optionally Gemini) CLI consultant flow in a project (wrapper scripts, CLAUDE.md policy section, scorecard), or when `tools/ask_codex.sh` / `tools/ask_gemini.sh` are missing but the project's CLAUDE.md references the consultant flow. Codex is required; Gemini is optional but recommended. Pairs with using-cli-consultants (the operational skill).
---

# Setting up CLI Consultants

## Overview

This skill installs the file-based Codex (+ optional Gemini) consultant flow in a project. After setup, the project has:

- `tools/ask_codex.sh` — required Codex wrapper
- `tools/ask_gemini.sh` — optional Gemini wrapper (skipped if Gemini CLI not installed on the host)
- A "CLI Consultants" section in `CLAUDE.md` declaring the policy
- `.agent/consultant_scorecard.md` for tracking dual-consultant calls

The runtime state (questions, answers) lives in `/tmp/{codex,gemini}_{question,answer}.txt`.

**Modes the install can produce:**

| Mode | Result | Operational consequence |
|---|---|---|
| **Full** | Both wrappers installed | Dual final-pass mandatory per operational policy |
| **Codex-only** | Only `tools/ask_codex.sh` | Single-Codex final-pass with mandatory `Gemini SKIPPED (not configured on this host)` disclosure in every report |

The operational counterpart is the `using-cli-consultants` skill — it tells the agent **when** and **how** to use the flow once it's installed, and how to operate in either mode.

## When to use this skill

- User says "set up consultant flow", "install Codex+Gemini consultants", or similar
- User wants to replicate the flow from another project ("same setup as in X")
- Project's `CLAUDE.md` references the flow but `tools/ask_*.sh` are missing
- Partial setup detected: scorecard or CLAUDE.md section missing

Do NOT run this if the project already has the wrappers installed — check first.

## Pre-flight checklist

Before installing, verify the host. Check each — if any fail, ask the user before proceeding (don't auto-install binaries):

```bash
# 1. Codex CLI on PATH — REQUIRED (need >= 0.117; tested on 0.125)
if ! command -v codex >/dev/null; then
    echo "ERROR: codex not found. Codex is required — install via npm before continuing."
    exit 1
fi
codex --version

# 2. Gemini CLI on PATH — OPTIONAL (need >= 0.40 if installed)
#    Absence is fine and expected on hosts where the teammate doesn't use Gemini.
#    The install will produce Codex-only mode in that case.
if command -v gemini >/dev/null; then
    GEMINI_INSTALLED=1
    gemini --version
else
    GEMINI_INSTALLED=0
    echo "Gemini CLI not detected — installing in Codex-only mode."
    echo "(Operational consequence: every consultation report carries the line"
    echo " 'Gemini SKIPPED (not configured on this host)'. See using-cli-consultants.)"
fi

# 3. nvm available (wrapper scripts use it to switch Node versions)
[ -s "$HOME/.nvm/nvm.sh" ] && echo "nvm: ok"

# 4. Detect the ACTUAL Node version each binary lives under.
#    This is NOT the same as "is Node 22 installed". The binaries may sit under
#    23.x or some other major. Pinning the wrong version in the wrapper makes
#    `nvm use` "succeed" but PATH stays on the system Node, and the script
#    falls through to "command not found" *after* the user already approved.
CODEX_NODE_VER=$(readlink -f "$(command -v codex)" | grep -oE 'node/v[0-9]+\.[0-9]+\.[0-9]+' | cut -d/ -f2 | sed 's/^v//')
echo "Codex lives under Node: ${CODEX_NODE_VER:-UNKNOWN}"

if [ "$GEMINI_INSTALLED" = 1 ]; then
    GEMINI_NODE_VER=$(readlink -f "$(command -v gemini)" | grep -oE 'node/v[0-9]+\.[0-9]+\.[0-9]+' | cut -d/ -f2 | sed 's/^v//')
    echo "Gemini lives under Node: ${GEMINI_NODE_VER:-UNKNOWN}"
fi
# If UNKNOWN: the binary is not under nvm (system install, brew, etc.) — the
# wrapper's `nvm use` line should be removed for that CLI, OR the user should
# reinstall the CLI under nvm. Surface this to the user before continuing.

# 5. Verify those exact Node versions are present (not just "any 22").
#    Match by major.minor.patch — a host may have v22.13 / v22.22 / v23.6 etc.
. "$HOME/.nvm/nvm.sh"
NODE_PATTERN="v${CODEX_NODE_VER}\b"
[ "$GEMINI_INSTALLED" = 1 ] && NODE_PATTERN="v(${CODEX_NODE_VER}|${GEMINI_NODE_VER})\b"
nvm ls | grep -E "$NODE_PATTERN"

# 6. /tmp is writable
touch /tmp/__consultant_setup_probe && rm /tmp/__consultant_setup_probe && echo "/tmp: ok"
```

The detected `CODEX_NODE_VER` / `GEMINI_NODE_VER` get sed'd into the wrapper templates at install time (see Step 3 below). **Do not hardcode versions** — that's how silent failures happen on hosts where the user only has Node 23.x.

**Version warning (if Gemini is installed):** Gemini < 0.40 does NOT support `--approval-mode plan` (only `default | auto_edit | yolo`) and `--resume` semantics differ. If the installed version is older, run `npm install -g @google/gemini-cli@latest` (with the user's permission) before installing the wrappers.

**If `codex` is missing:** stop and tell the user. Don't `npm install -g` without permission — the CLI is user-owned. Codex is required.

**If `gemini` is missing:** proceed with Codex-only install. Surface to the user that the result will be Codex-only mode (operational consequence: dual final-pass downgrades to single-Codex final-pass with a mandatory `Gemini SKIPPED` disclosure line in every report). If they later install Gemini, they can re-run this skill — it's idempotent and will add the missing wrapper.

**If nvm is missing OR a binary lives outside nvm:** surface this; the user decides between (a) reinstalling the CLI under nvm, or (b) removing the `nvm use` line from that wrapper.

## CLI flag reference (current as of Codex 0.125 / Gemini 0.40)

| Concern | Codex | Gemini |
|---|---|---|
| Read-only sandbox | `-s read-only` | `--approval-mode plan` |
| Resume a session | `codex exec -s read-only resume <UUID>` (or `--last`) | `gemini --resume latest` (or `--resume <index>` — NOT a UUID) |
| Output to file | `-o, --output-last-message <FILE>` | redirect stdout (`> file`) |
| Non-interactive prompt | positional or stdin | `-p ""` with stdin pipe |
| List sessions | `codex resume --all` (interactive picker) | `gemini --list-sessions` |
| Default model | `model` in `~/.codex/config.toml` (override with `-m`) | `model.name` in `~/.gemini/settings.json` (override with `-m`) |

The `-m` / `--model` flag on either side overrides the configured default. If reproducibility matters, pin the model explicitly — either in the wrapper script via `-m`, or globally:

**Codex** (`~/.codex/config.toml`):
```toml
model = "gpt-5.5"
model_reasoning_effort = "xhigh"
```

**Gemini** (`~/.gemini/settings.json`):
```json
{
  "model": { "name": "gemini-3.1-pro-preview" }
}
```

Note: model availability depends on the user's auth tier. With `oauth-personal`, free Code Assist may restrict which models are routable. Verify with `gemini -m <id> -p "ping" --skip-trust` — a 404 means the model is unavailable to your account.

## Installation

The skill ships four templates in `templates/`:

| Template file | Destination in project | Conditional |
|---|---|---|
| `ask_codex.sh` | `tools/ask_codex.sh` | always |
| `ask_gemini.sh` | `tools/ask_gemini.sh` | only if `$GEMINI_INSTALLED=1` |
| `CLAUDE_SECTION.md` | append/merge into project `CLAUDE.md` | always |
| `consultant_scorecard.md` | `.agent/consultant_scorecard.md` | always (used in dual mode; harmless in Codex-only) |

### Steps

1. **Find the skill's template directory.** When invoked through the plugin, templates live under `${CLAUDE_PLUGIN_ROOT}/skills/setting-up-cli-consultants/templates`. As a fallback for personal install:
   ```bash
   SKILL_DIR="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/skills}/setting-up-cli-consultants/templates"
   [ -d "$SKILL_DIR" ] || SKILL_DIR="$HOME/.claude/plugins/cache/team-cli-consultant/cli-consultants/skills/setting-up-cli-consultants/templates"
   ls "$SKILL_DIR"
   ```

2. **Copy wrapper scripts and make them executable** (Gemini conditionally):
   ```bash
   mkdir -p tools
   cp "$SKILL_DIR/ask_codex.sh" tools/ask_codex.sh
   chmod +x tools/ask_codex.sh

   if [ "$GEMINI_INSTALLED" = 1 ]; then
       cp "$SKILL_DIR/ask_gemini.sh" tools/ask_gemini.sh
       chmod +x tools/ask_gemini.sh
   fi
   ```

3. **Pin Node versions in the wrappers** (required — see pre-flight #4):
   ```bash
   sed -i "s|__REPLACE_WITH_CODEX_NODE_VERSION__|$CODEX_NODE_VER|" tools/ask_codex.sh

   if [ "$GEMINI_INSTALLED" = 1 ]; then
       sed -i "s|__REPLACE_WITH_GEMINI_NODE_VERSION__|$GEMINI_NODE_VER|" tools/ask_gemini.sh
   fi
   ```
   Verify the substitutions:
   ```bash
   grep "nvm use" tools/ask_codex.sh
   [ -f tools/ask_gemini.sh ] && grep "nvm use" tools/ask_gemini.sh
   # Should print real versions, not the __REPLACE_WITH_*__ placeholders.
   ```
   If a binary lives outside nvm (Step 4 above returned `UNKNOWN`): delete the `nvm use` line from the corresponding wrapper instead of running the sed.

4. **Configure session references.**
   - **Codex:** the template has `SESSION_ID="__REPLACE_WITH_CODEX_SESSION_ID__"`. After creating the session (see "Session creation" below), `sed -i` the UUID in.
   - **Gemini (only if installed):** the template defaults to `SESSION_REF="latest"` — no replacement needed unless you maintain multiple consultant sessions per project. In that case, run `gemini --list-sessions`, pick the index, and edit the variable.

5. **Install the scorecard:**
   ```bash
   mkdir -p .agent
   cp "$SKILL_DIR/consultant_scorecard.md" .agent/consultant_scorecard.md
   ```

6. **Add the policy section to CLAUDE.md.** The `CLAUDE_SECTION.md` template is body-only (no instruction comments), so a plain append is safe:
   ```bash
   # If CLAUDE.md exists: append (with separator).
   { echo ""; echo "---"; echo ""; cat "$SKILL_DIR/CLAUDE_SECTION.md"; } >> CLAUDE.md
   # If it doesn't exist: create.
   [ -f CLAUDE.md ] || cp "$SKILL_DIR/CLAUDE_SECTION.md" CLAUDE.md
   ```
   Adjust voice/wording afterwards to match the project's style — but keep the policy table intact.

7. **Verify:**
   ```bash
   ls -la tools/ask_codex.sh .agent/consultant_scorecard.md
   [ -f tools/ask_gemini.sh ] && echo "gemini wrapper: present (Full mode)" \
                              || echo "gemini wrapper: absent (Codex-only mode)"
   grep -q "CLI Consultants" CLAUDE.md && echo "CLAUDE.md: ok"
   # Smoke test (only if sessions are already created — otherwise expect an error):
   echo "ping" > /tmp/codex_question.txt && ./tools/ask_codex.sh
   ```

## Session creation

Each wrapper resumes a **persistent CLI session** preloaded with project context. The session must be created before the wrapper works. Two paths:

### Path A — manual (recommended for first-time setup)

The user runs the CLI interactively, primes it with project docs, exits, and captures the session ID. Steps to give the user:

**Codex:**
1. From the project root: `codex` (interactive shell).
2. Inside, ask Codex to read the most important orienting docs — typical examples: `cat ARCHITECTURE.md` (or whatever exists), then a directory tree (`tree -L 3 src/` or `ls -R src/ | head -200`), then any other top-level docs that establish architecture conventions.
3. Exit. Codex prints/persists the session ID (location depends on CLI version — usually shown on exit or stored in `~/.codex/sessions/`).
4. User pastes the session ID into `tools/ask_codex.sh`, replacing `__REPLACE_WITH_CODEX_SESSION_ID__`.

**Gemini (CLI 0.40+) — skip this block in Codex-only mode (`GEMINI_INSTALLED=0`):**
1. From the project root: `gemini` (interactive shell, no `--resume` for a fresh session).
2. Inside, ask Gemini to read the same orienting docs as Codex (so the two sessions start with comparable context).
3. Exit. The session is auto-saved per project.
4. Verify with `gemini --list-sessions` — should show your new session at the top.
5. **Do NOT paste a session ID** into `tools/ask_gemini.sh` — the wrapper already uses `--resume latest` by default. If you maintain multiple consultant sessions per project, run `--list-sessions`, pick the index of the right one, and replace `SESSION_REF="latest"` with `SESSION_REF="<index>"`.

### Path B — semi-automated

If the user explicitly approves, the agent can prime a session non-interactively and capture the new session ID by snapshotting `~/.codex/sessions/` before/after. Working pattern (verified on Codex 0.125):

```bash
# 1. Compose the priming prompt. Pick orienting docs that exist in the repo —
#    ARCHITECTURE.md / README.md / a few key src files / a directory listing.
#    The agent decides what counts as "project context" here, hence Path B
#    needs explicit user approval.
PRIME=$(cat <<'EOF'
Read the following files and produce a 3-5 bullet summary of the project's
architecture. After that, you are this project's read-only architecture
consultant: future questions will resume this session and ask you about
design decisions, spec reviews, and implementation verification.

Files to read:
- README.md
- ARCHITECTURE.md   (if present)
- package.json
- A directory listing of src/ depth 2
EOF
)

# 2. Snapshot the moment before the call so we can find the new session file.
T0=$(date -u +%s)

# 3. Run codex non-interactively in read-only sandbox. -o captures the answer
#    (also useful as a sanity-check that the priming actually happened).
codex exec -s read-only "$PRIME" -o /tmp/codex_prime_answer.txt 2>/tmp/codex_prime_stderr.log

# 4. Find the rollout file created during the call and extract the UUID from
#    its filename: rollout-YYYY-MM-DDTHH-MM-SS-<UUID>.jsonl
SESSION_ID=$(find ~/.codex/sessions/ -name 'rollout-*.jsonl' -newermt "@$T0" \
    | head -1 \
    | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')
echo "Captured Codex session: $SESSION_ID"

# 5. Sed it into the wrapper.
sed -i "s|__REPLACE_WITH_CODEX_SESSION_ID__|$SESSION_ID|" tools/ask_codex.sh
```

For Gemini under Path B: prime via `gemini -p "$PRIME" --approval-mode plan` (or with `--skip-trust` / `GEMINI_CLI_TRUST_WORKSPACE=true` if the workspace isn't trusted yet), then verify with `gemini --list-sessions`. The `latest` default in the wrapper picks it up automatically — no sed needed unless you maintain multiple sessions per project. Note: Gemini will print 429 retry chatter to stderr even on success; redirect to a log if the noise is alarming.

### Smoke-test

After either path, verify the wrappers actually round-trip a question:

```bash
# Codex
echo "List the top 3 architectural risks in this codebase, briefly." > /tmp/codex_question.txt
./tools/ask_codex.sh

# Gemini — note the read-only prefix from the operational policy
cat > /tmp/gemini_question.txt <<'EOF'
Read-only consultation. Do not edit any files — analysis only.

List the top 3 architectural risks in this codebase, briefly.
EOF
./tools/ask_gemini.sh
```

Expected: a paragraph or two of architectural commentary in each `_answer.txt`. The Gemini smoke test mirrors the operational skill's required prefix on purpose — even though `--approval-mode plan` already blocks writes, including the prefix here builds the right muscle memory for actual consultations.

In **Codex-only mode** (`tools/ask_gemini.sh` not installed), skip the second smoke test block — it has nothing to call. The Codex one is sufficient.

Empty output or session-not-found errors → check `/tmp/{codex,gemini}_stderr.log` (see Troubleshooting).

## Common gaps to watch for

Based on what agents miss without this skill:

| Gap | Mitigation |
|---|---|
| Inventing a different file layout (`tools/consult-codex.sh`, `tools/dual-review.sh`, `tools/consults/` etc.) | Use the canonical names verbatim: `tools/ask_codex.sh`, `tools/ask_gemini.sh`. Don't add a `dual-review.sh` — the operational skill runs them in parallel via shell `&` instead. |
| Missing sandbox flags | `-s read-only` (Codex) and `--approval-mode plan` (Gemini) are required, not optional. They're already in the templates — don't strip them. |
| Forgetting `nvm use` | Both wrappers source nvm and pin a Node version. Without this, the script silently fails on hosts whose default Node is older than the CLI requires. |
| Skipping the `/tmp` file convention | The wrappers are deliberately file-based so the agent only needs one Bash approval per script, not per question. Don't change the question/answer file paths. |
| Skipping the Gemini read-only prefix in the operational policy | This belongs in the operational skill (`using-cli-consultants`), not the wrappers — the prefix is in the prompt text, not the script. Make sure the user knows about it. |

## Troubleshooting

The wrappers redirect stderr to log files instead of `/dev/null` so failures are diagnosable. When a call returns empty output or unexpected content, read the logs:

```bash
cat /tmp/codex_stderr.log
cat /tmp/gemini_stderr.log
```

| Symptom | Likely cause | Action |
|---|---|---|
| `tools/ask_codex.sh: line N: codex: command not found` | The wrapper's pinned Node version has no codex installed under it. Almost always: `nvm use` switched away from the version that hosts codex. | Re-run pre-flight Step 4 (`readlink -f $(command -v codex)`); ensure the wrapper's `nvm use <X>` matches the binary's actual Node version. |
| Empty `/tmp/codex_answer.txt` | Bad / expired session UUID, or codex auth issue | `cat /tmp/codex_stderr.log`; if "session not found" → re-prime (Path A or B); if auth → `codex login`. |
| `404` from gemini | Model in `~/.gemini/settings.json` not available to the auth tier | Switch model (e.g. `gemini-2.5-pro` is widely available on `oauth-personal`), or remove the `model.name` override to fall back to CLI default. |
| Gemini stderr full of red `Too Many Requests / 429` lines but `/tmp/gemini_answer.txt` is populated and exit 0 | **Normal** — Gemini retries 429s internally. The retry chatter is noisy but the call succeeded. | Ignore. If it happens repeatedly within a short window, slow down the consult cadence. |
| `Approval mode overridden to "default" because the current folder is not trusted` | Gemini refuses `--approval-mode plan` outside trusted workspaces | Set `GEMINI_CLI_TRUST_WORKSPACE=true` for the call, or trust the workspace interactively once. The wrapper is best invoked from the project root after that. |
| Codex returns the previous answer | Output file wasn't rewritten (silent rejection upstream) | `stat /tmp/codex_answer.txt` — if mtime is stale, check `/tmp/codex_stderr.log` and re-run. |
| Both consultants disagree confidently | Genuine non-falsifiable design choice | Per operational skill: iterate up to 4 rounds, escalate to user if no convergence. Don't pick a side without a tie-break. |

## Adapting templates

The templates are starting points. Reasonable adaptations:

- Wording in the CLAUDE.md section (project voice, formatting style)
- Adding extra columns to the scorecard (e.g., `severity`, `pr_link`)
- Adjusting Node version pins if the user runs different versions

Do **not** adapt:

- The sandbox flags
- The session-resume mechanism
- The `/tmp/{codex,gemini}_{question,answer}.txt` file convention
- The policy table's mandatory rows

These are load-bearing for the operational skill to work.

## Reporting back

After installation, tell the user:

1. **Mode chosen** — `Full` (Codex + Gemini wrappers) or `Codex-only` (only `tools/ask_codex.sh`). If Codex-only, name the operational consequence: every consultation report will carry the `Gemini SKIPPED (not configured on this host)` disclosure line.
2. Files created/modified (paths)
3. Pre-flight checklist results (binaries found, Node versions OK)
4. Session creation status — done, or pending user action (per applicable wrapper)
5. Smoke test result, if sessions were created
6. Next step — typically: "Sessions need to be primed manually. Walk me through it when ready, or grant me Bash autonomy to do Path B." In Codex-only mode, mention that re-running this skill after installing Gemini will upgrade the project to Full mode (the install is idempotent).

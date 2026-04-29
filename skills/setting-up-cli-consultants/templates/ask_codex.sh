#!/usr/bin/env bash
# Consult Codex on project architecture/planning questions.
#
# Usage:
#   1. Write question to /tmp/codex_question.txt
#   2. Run: ./tools/ask_codex.sh
#   3. Read answer from /tmp/codex_answer.txt
#
# This file-based design lets the agent approve the script once, then
# reuse it for any question by changing only the question file.

set -euo pipefail

# Pin to the Node version under which `codex` was actually installed.
# The setup skill detects this at install time via `readlink -f $(command -v codex)`
# and seds it in. Hardcoded versions silently break when the binary lives under
# a different Node (e.g. 23.x) — `nvm use` "succeeds" but PATH is wrong and the
# script then falls through to "command not found" after the user already approved.
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm use __REPLACE_WITH_CODEX_NODE_VERSION__ >/dev/null 2>&1 || true

SESSION_ID="__REPLACE_WITH_CODEX_SESSION_ID__"
QUESTION_FILE="/tmp/codex_question.txt"
OUTPUT_FILE="/tmp/codex_answer.txt"
STDERR_LOG="/tmp/codex_stderr.log"

if [ ! -f "$QUESTION_FILE" ]; then
    echo "Error: $QUESTION_FILE not found. Write your question there first." >&2
    exit 1
fi

if [ ! -s "$QUESTION_FILE" ]; then
    echo "Error: $QUESTION_FILE is empty." >&2
    exit 1
fi

QUESTION=$(cat "$QUESTION_FILE")

# -s read-only locks the sandbox: Codex CANNOT write/edit files.
# resume "$SESSION_ID" continues the persistent session preloaded with project context.
# -o writes the answer to a file; we also cat it for the agent's stdout.
# stderr goes to a log file (overwritten each run) so failures (expired session,
# bad UUID, 429, network) are diagnosable instead of silently producing empty output.
codex exec -s read-only resume "$SESSION_ID" "$QUESTION" -o "$OUTPUT_FILE" 2>"$STDERR_LOG"

cat "$OUTPUT_FILE"

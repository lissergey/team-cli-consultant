#!/usr/bin/env bash
# Consult Gemini on project architecture/planning questions.
#
# Usage:
#   1. Write question to /tmp/gemini_question.txt
#   2. Run: ./tools/ask_gemini.sh
#   3. Read answer from /tmp/gemini_answer.txt
#
# Same file-based design as ask_codex.sh: approve the script once,
# reuse it for any question by rewriting the question file.

set -euo pipefail

# Pin to the Node version under which `gemini` was actually installed.
# The setup skill detects this at install time via `readlink -f $(command -v gemini)`
# and seds it in. Hardcoded versions silently break when the binary lives under
# a different Node — `nvm use` "succeeds" but PATH is wrong and the script then
# falls through to "command not found" after the user already approved.
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm use __REPLACE_WITH_GEMINI_NODE_VERSION__ >/dev/null 2>&1 || true

# Gemini CLI 0.40+ takes "latest" or a numeric index (NOT a UUID) for --resume.
# "latest" is the safest default if you keep ONE persistent consultant session
# per project. To pin a specific session by index, run `gemini --list-sessions`
# and replace SESSION_REF with the index number.
SESSION_REF="latest"
QUESTION_FILE="/tmp/gemini_question.txt"
OUTPUT_FILE="/tmp/gemini_answer.txt"
STDERR_LOG="/tmp/gemini_stderr.log"

if [ ! -f "$QUESTION_FILE" ]; then
    echo "Error: $QUESTION_FILE not found. Write your question there first." >&2
    exit 1
fi

if [ ! -s "$QUESTION_FILE" ]; then
    echo "Error: $QUESTION_FILE is empty." >&2
    exit 1
fi

# --approval-mode plan = read-only (no file edits, no shell writes).
# Question is piped via stdin; -p "" leaves prompt empty so stdin becomes the prompt.
# Bypasses argv length limits for long prompts.
# stderr silenced because gemini prints "Loaded cached credentials." on every call.
# --approval-mode plan = read-only (no file edits, no shell writes).
# Question is piped via stdin; -p "" leaves prompt empty so stdin becomes the prompt.
# stderr -> log file (overwritten each run). Gemini retries 429s automatically and
# still exits 0, but the retry chatter goes to stderr — having a log avoids panic.
cat "$QUESTION_FILE" | gemini \
    --resume "$SESSION_REF" \
    --approval-mode plan \
    -p "" \
    > "$OUTPUT_FILE" 2>"$STDERR_LOG"

cat "$OUTPUT_FILE"

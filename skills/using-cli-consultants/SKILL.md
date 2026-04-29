---
name: using-cli-consultants
description: Use when about to draft an architecture/design spec, write or finalize an implementation plan, verify an implementation against its spec, or facing a non-trivial architecture/design judgment call. Skip for trivial naming/wording/style choices that belong to the user. Requires `tools/ask_codex.sh` and `tools/ask_gemini.sh` in the project; if missing, see setting-up-cli-consultants.
---

# Using CLI Consultants

## Overview

Codex and Gemini run as **read-only persistent CLI sessions** that know the project. You consult them via file-based wrapper scripts:

- `tools/ask_codex.sh` — Codex (primary architecture/design reviewer)
- `tools/ask_gemini.sh` — Gemini (second-opinion reviewer for final passes)

Two independent models catch each other's blind spots. Both can read the live repo and cite file paths, so claims are checkable.

## Policy table — when each is mandatory

| Situation | Codex | Gemini |
|---|---|---|
| Quick architecture sanity-check / design clarification | mandatory | optional |
| Spec draft — iterations 1..N-1 | mandatory | not needed |
| **Spec — final pass (before declaring it ready)** | **mandatory** | **mandatory (parallel)** |
| Plan draft — iterations 1..N-1 | mandatory | not needed |
| **Plan — final pass (before implementation)** | **mandatory** | **mandatory (parallel)** |
| **Verify implementation against spec/plan** | **mandatory** | **mandatory (parallel)** |
| Tie-break on disagreement | engage both iteratively until convergence | |

**Don't overuse.** Trivial choices (variable naming, wording, formatting, single-line code style) go to the user directly, never to consultants.

## The discipline this skill enforces

**Final-pass dual is mandatory regardless of how confident Codex is, how many rounds you ran, or how solid the artifact looks.** Gemini is a *different* model with different blind spots — not a rehash. The dual pass costs ~10 minutes; missing a load-bearing failure mode costs weeks.

### Rationalizations — STOP if you think any of these

| Excuse | Reality |
|---|---|
| "Codex already signed off twice — Gemini would just rehash" | Gemini is a *different model*. If they always agreed, dual pass would be pointless. The value is in the divergence. |
| "Plan looks solid, covers everything" | "Looks solid" is exactly when blind spots hide. That's the case dual-pass is built for. |
| "We're past the design phase / have momentum" | Sunk cost is not an argument. The cost of one Gemini call is 10 minutes; the cost of a missed failure mode is the rest of the quarter. |
| "User told me to skip the extra round" | The user owns scope and priority; the consultant policy is your discipline, not theirs to waive. State the cost of skipping and run the dual anyway, or explicitly escalate ("policy says dual final-pass — skip on your call?"). Do not silently comply. |
| "Time pressure" | Unless the deadline is < 15 min away, the dual pass fits. If it truly doesn't, run Codex final + flag in the report that Gemini was deferred. |
| "Trivial change to a final artifact" | If it's trivial, the dual pass returns "no concerns" in 2 minutes. Run it anyway — the cost asymmetry is overwhelming. |

**Violating the letter of the policy is violating the spirit.** Don't rationalize.

## How to invoke

### Single consultant (Codex on iterations 1..N-1)

```bash
# 1. Write the question
cat > /tmp/codex_question.txt <<'EOF'
[your structured question — see Prompt structure below]
EOF

# 2. Run the wrapper (output goes to stdout AND /tmp/codex_answer.txt)
./tools/ask_codex.sh
```

If the wrapper hangs or returns silently, see Failure modes.

### Dual final-pass (parallel)

Always run them in parallel, never sequentially:

```bash
# Write both question files (usually identical or near-identical)
cat > /tmp/codex_question.txt <<'EOF' ...
cat > /tmp/gemini_question.txt <<'EOF' ...

# Fire in parallel via background processes
bash -lc '. ~/.nvm/nvm.sh && nvm use 22  >/dev/null 2>&1; ./tools/ask_codex.sh  > /tmp/codex_run.log 2>&1' &
bash -lc '. ~/.nvm/nvm.sh && nvm use 22.5.1 >/dev/null 2>&1; ./tools/ask_gemini.sh > /tmp/gemini_run.log 2>&1' &
wait

# Read both answers and synthesize
```

**Note on Bash tool timeout:** consultant calls can take 2-5 minutes. Set `timeout: 300000` on the Bash invocation, otherwise the default 2-minute timeout truncates the call.

## Prompt structure that works

Every consultation prompt should contain:

1. **One-line goal** — what you're trying to decide.
2. **Context block** — relevant file paths, snippets, existing state.
3. **Numbered specific questions** — "is X correct?", "is Y missing?", "what's wrong with Z?".
4. **What you've already considered** — your instinct + alternatives ruled out.
5. **Boundary** — "read-only", "be specific", "flag anything load-bearing".

**Anti-patterns:** wall-of-text without numbered questions; vague "what do you think?"; asking the consultant to write code.

### Gemini read-only prefix (REQUIRED)

Always prefix the Gemini question text with:

> Do not modify any files. Analysis/review only — read and grep the repo as needed, but no edits, no writes, no shell side-effects.

The CLI's `--approval-mode plan` blocks actual writes, but Gemini sometimes attempts them anyway and burns tokens on rejection dialogue. The explicit instruction reduces waste.

Codex respects `-s read-only` reliably — no prefix needed.

## Reporting back to the user

After every consultation, give a brief report:

- **Single call:** "Asked Codex about X. It said Y. I agree / I disagree because Z."
- **Dual final-pass:** "Asked both about X. Codex: Y₁. Gemini: Y₂. Convergence on A, B; divergence on C — taking Codex's view because [reason] / escalating C to user."
- **On failure:** "Codex unreachable (timeout / empty answer). Continuing independently with [decision]; flag for re-review when consultant available."

## Scorecard (dual cases only)

When a consultation invoked **both** consultants on a mandatory item or tie-break, append a row to `.agent/consultant_scorecard.md` (schema is in that file's header). Single-consultant calls are not logged.

Fields capture: date, artifact, task type, question, each consultant's TL;DR, your eval (correct / partial / wrong / irrelevant / timeout), winner, ground truth (`?` if not yet known), notes on who missed what.

## Failure modes (real, observed)

| Symptom | Cause | Fix |
|---|---|---|
| Codex script returns empty answer | Node version mismatch in non-interactive bash, or stale session | Read `/tmp/codex_stderr.log`. If the wrapper's pinned `nvm use <X>` doesn't match the binary's actual Node version, fix the pin (see setting-up-cli-consultants). If session expired, re-prime. |
| Codex returns previous answer | Output file wasn't rewritten (silent rejection) | Check `stat /tmp/codex_answer.txt` mtime against `date +%s` before reading; consult `/tmp/codex_stderr.log`. |
| Gemini stderr full of red `429 / Too Many Requests` lines but answer is populated and exit 0 | **Normal** — Gemini retries 429s internally | Ignore the stderr noise. If it happens repeatedly within minutes, slow down consult cadence. |
| `404` from Gemini | Configured model unavailable to the auth tier | Switch model in `~/.gemini/settings.json` or remove the `model.name` override. |
| Gemini hangs ≥ 5 min | CLI session issue | Bump Bash tool timeout to 300000+; if still hangs, mark unreachable, continue independently. |
| `Approval mode overridden ... folder not trusted` | Gemini refuses `--approval-mode plan` outside trusted workspaces | Set `GEMINI_CLI_TRUST_WORKSPACE=true` for the call, or trust the workspace once interactively. |
| Both disagree confidently | Genuine non-falsifiable design choice | Iterate (give each the other's view) up to 4 rounds; if no convergence, escalate to user with both views — don't pick a side. |
| Consultant unreachable (network/quota) | Outage | Continue independently, mark in report — do not block. |

## Don't block

If a consultant is unreachable or returns an unclear answer, **continue independently** and note it in the report. The skill is a quality lever, not a hard gate. The only hard rule is: don't claim the dual final-pass happened when it didn't.

## Red flags — STOP and reconsider

- About to commit a final spec/plan without Gemini's pass
- Thinking "Codex already said yes, no point asking Gemini"
- Thinking "user told me to skip — they decided"
- Running dual sequentially instead of parallel
- Skipping the Gemini read-only prefix
- About to consult on a naming/style/wording choice

Each of these means: stop, run the canonical flow.

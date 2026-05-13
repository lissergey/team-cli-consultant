---
name: using-cli-consultants
description: Use when about to draft an architecture/design spec, write or finalize an implementation plan, verify an implementation against its spec, or facing a non-trivial architecture/design judgment call. Skip for trivial naming/wording/style choices that belong to the user. Requires `tools/ask_codex.sh` in the project; `tools/ask_gemini.sh` is optional but enables stronger dual final-pass discipline; Plan-subagent (via Claude Code Agent tool) is always available as a third optional channel and fills in for unreachable consultants. If wrappers missing, see setting-up-cli-consultants.
---

# Using CLI Consultants

## Overview

Three independent reviewers, each with different blind spots:

- `tools/ask_codex.sh` — **Codex** (primary architecture/design reviewer; **required**)
- `tools/ask_gemini.sh` — **Gemini** (second-opinion reviewer for final passes; **optional but recommended**)
- **Plan-subagent** — Claude Code's `Agent` tool with `subagent_type=Plan, model=opus`; **always available** in any Claude Code session; **optional but recommended for final-pass and as a fallback** when Codex is rate-limited or Gemini is drifting

Codex and Gemini run as **read-only persistent CLI sessions** that know the project. Plan-subagent is different: **fresh context per call** (no accumulated review history), no rate-limit, no context-drift, but pays the cost of re-loading orienting context every call. The three together catch a wider class of bugs than any pair — Plan-subagent specifically catches execution-readiness issues (broken indentation after iterative edits, fictional API refs, wire-shape gaps) that persistent-context reviewers systematically miss because they accumulate "we already discussed this" bias.

When only Codex is configured (Gemini wrapper absent), Plan-subagent compensates as the second voice for final-passes — see "Codex-only mode" below. Pure single-consultant mode is no longer the default fallback; if Codex is also down, escalate to the user.

## Detecting available consultants

Before any consultation, check what's wired up in the project and what's available in the runtime:

```bash
[ -x tools/ask_codex.sh ]  && CODEX_AVAILABLE=1  || CODEX_AVAILABLE=0
[ -x tools/ask_gemini.sh ] && GEMINI_AVAILABLE=1 || GEMINI_AVAILABLE=0
# Plan-subagent: available whenever Claude Code's Agent tool exists in this session.
# Treat as ALWAYS available; if the runtime lacks Agent tool, this whole skill is moot anyway.
PLAN_SUBAGENT_AVAILABLE=1
```

- `CODEX_AVAILABLE=0` → the operational policy can't run; either install Codex (see `setting-up-cli-consultants`), use Plan-subagent as full replacement, or work without consultants and disclose this to the user.
- `GEMINI_AVAILABLE=0` → **Codex-only-plus-Plan mode** (see below). Final-pass dual degrades to Codex + Plan-subagent quasi-dual with a softer mandatory disclosure line.
- All three available → full triple-eligible policy. Dual final-pass (Codex + Gemini) remains the default; Plan-subagent is optional bonus and mandatory only on tie-break.

## Policy table — when each is mandatory

| Situation | Codex | Gemini (if configured) | Plan-subagent |
|---|---|---|---|
| Quick architecture sanity-check / design clarification | mandatory | optional | optional |
| Spec draft — iterations 1..N-1 | mandatory | not needed | optional |
| **Spec — final pass (before declaring it ready)** | **mandatory** | **mandatory (parallel)** | optional bonus voice |
| Plan draft — iterations 1..N-1 | mandatory | not needed | optional |
| **Plan — final pass (before implementation)** | **mandatory** | **mandatory (parallel)** | optional bonus voice |
| **Verify implementation against spec/plan** | **mandatory** | **mandatory (parallel)** | optional bonus voice |
| Tie-break on Codex/Gemini disagreement | engage both iteratively until convergence | | **mandatory deciding voice** |
| **Codex rate-limited / unreachable** | n/a | works | **mandatory replacement** |
| **Gemini drifting** (answering about a different phase / referencing nonexistent files) | works | ignore answer | **mandatory replacement** |

**Codex-only-plus-Plan mode (when `tools/ask_gemini.sh` is absent but Plan-subagent is available):** Replace every "mandatory dual" cell above with "Codex + Plan-subagent quasi-dual pass + explicit `Gemini SKIPPED (not configured on this host); Plan-subagent compensating as second voice` line in the consultation report". The discipline does NOT vanish — Plan-subagent's fresh-context first-read covers most of what Gemini would have caught. Reports without the disclosure line are not allowed.

**Don't overuse.** Trivial choices (variable naming, wording, formatting, single-line code style) go to the user directly, never to consultants — including Plan-subagent.

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
| "Gemini wrapper exists but I'll claim it doesn't to skip" | Lying about environment to escape policy is the discipline failure the skill exists to prevent. The runtime check `[ -x tools/ask_gemini.sh ]` is the ground truth, not your assertion. |
| "I'll just skip installing Gemini in this project to avoid dual final-pass" | Codex-only mode is a cost paid in disclosure (every report carries `Gemini SKIPPED`). Choosing it deliberately to escape discipline is observable in the scorecard and report trail. The right move when Gemini is genuinely unavailable: accept Codex-only and disclose. The wrong move: install-skip as policy laundering. |
| "Reports don't really need the `Gemini SKIPPED` line, the user can see Gemini isn't installed" | Wrong. The disclosure is non-optional in Codex-only mode. It's how you and the user track when single-pass was used vs. dual, for retrospective calibration of misses. |
| "Plan-subagent is optional, so I'll skip it on tie-break to save tokens" | Tie-break is one of the two cases where Plan-subagent is **mandatory**, not optional. Picking a winner between two confidently-disagreeing models without a fresh-context third voice is exactly the failure mode this role exists to prevent. |
| "Codex came back 429, I'll just proceed with Gemini alone and disclose later" | When Codex is unreachable, Plan-subagent is the mandatory replacement, not Gemini-alone. Skipping it forfeits the independent voice the policy requires. Disclose Codex-was-down AND that Plan-subagent took over. |

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

### Final-pass (dual or single, depending on what's available)

```bash
# Detect mode at consultation time
[ -x tools/ask_gemini.sh ] && GEMINI_AVAILABLE=1 || GEMINI_AVAILABLE=0
```

**Dual mode (`GEMINI_AVAILABLE=1`)** — run them in parallel, never sequentially:

```bash
# Write both question files (usually identical or near-identical)
cat > /tmp/codex_question.txt  <<'EOF' ...
cat > /tmp/gemini_question.txt <<'EOF' ...

# Fire in parallel via background processes (the wrappers handle nvm internally)
./tools/ask_codex.sh  > /tmp/codex_run.log  2>&1 &
./tools/ask_gemini.sh > /tmp/gemini_run.log 2>&1 &
wait

# Read both answers and synthesize. Report convergence/divergence.
```

**Codex-only mode (`GEMINI_AVAILABLE=0`)** — single Codex final-pass, with mandatory disclosure:

```bash
cat > /tmp/codex_question.txt <<'EOF' ...
./tools/ask_codex.sh
```

In the report back to the user, the line **`Gemini SKIPPED (not configured on this host)`** is non-optional. See "Reporting back" below.

**Note on Bash tool timeout:** consultant calls can take 2-5 minutes. Set `timeout: 300000` on the Bash invocation, otherwise the default 2-minute timeout truncates the call.

### Plan-subagent invocation

Plan-subagent runs in-session through Claude Code's `Agent` tool — no CLI, no `/tmp/` files. One self-contained call per consultation; never a follow-up (each call is a full re-spawn with no memory of prior calls).

```
Agent({
  description: "Fresh-eyes review of <doc> at <sha>",
  subagent_type: "Plan",
  model: "opus",
  prompt: <see PLAN_SUBAGENT_PROMPT.md template from setting-up-cli-consultants>
})
```

Required prompt sections (full template lives at `${CLAUDE_PLUGIN_ROOT}/skills/setting-up-cli-consultants/templates/PLAN_SUBAGENT_PROMPT.md`):

1. **Context** — who you are, project, doc path + commit SHA + frontmatter version
2. **Background** — 2 paragraphs: what the doc describes, what foundation it builds on (Plan-subagent has no conversation history)
3. **Review history** — rounds count, who participated, closed BLOCKERs, why fresh eyes are needed now
4. **Critical files to grep** — explicit paths + approximate line numbers for claim verification (saves the subagent's time)
5. **Task** — 7-8 numbered review sections including the mandatory agent-execution check (see "Prompt structure that works" below)
6. **Output format** — numbered findings with severity (BLOCKER / IMPORTANT / NICE-TO-HAVE / OK); end with verdict (`ship-as-is / fix-then-ship / iter-N needed`)
7. **Constraints** — read-only; do NOT modify any files

**Parallel triple final-pass** (when running Plan-subagent alongside Codex + Gemini as bonus voice):

```bash
# Fire CLI consultants in parallel as usual
./tools/ask_codex.sh  > /tmp/codex_run.log  2>&1 &
./tools/ask_gemini.sh > /tmp/gemini_run.log 2>&1 &
# Plan-subagent in the SAME orchestration step: dispatch it as an Agent tool call
# in the same message that fires the wrappers. The agent runtime parallelizes.
wait  # for the bash backgrounds
# Plan-subagent completion is signaled by Agent tool result.
```

## Prompt structure that works

Every consultation prompt should contain:

1. **One-line goal** — what you're trying to decide.
2. **Context block** — relevant file paths, snippets, existing state.
3. **Numbered specific questions** — "is X correct?", "is Y missing?", "what's wrong with Z?".
4. **What you've already considered** — your instinct + alternatives ruled out.
5. **Boundary** — "read-only", "be specific", "flag anything load-bearing".

**Anti-patterns:** wall-of-text without numbered questions; vague "what do you think?"; asking the consultant to write code.

### Mandatory final-pass question (REQUIRED for final-pass prompts)

Every final-pass prompt (for any consultant — Codex, Gemini, Plan-subagent) MUST include verbatim:

> **Would a fresh subagent with no prior context execute this spec/plan correctly on first try, without UnboundLocalErrors, deadlocks, missing variable references, or undefined helpers? Are all task boundaries self-contained?**

This is a **separate dimension** from architectural correctness. A spec can be architecturally pristine but contain undefined helper functions, implicit dependencies between tasks, missing cleanup after failure — these only surface at implementation time. The severity label `BLOCKER (Agent Execution)` was introduced after iterative review missed exactly this class of bug; without an explicit question, agent-execution issues pass architectural-LGTM unnoticed.

Skip in iter-1..N-1 prompts (those are about architecture maturation). Required in final-pass only.

### Gemini read-only prefix (REQUIRED)

Always prefix the Gemini question text with:

> Do not modify any files. Analysis/review only — read and grep the repo as needed, but no edits, no writes, no shell side-effects.

The CLI's `--approval-mode plan` blocks actual writes, but Gemini sometimes attempts them anyway and burns tokens on rejection dialogue. The explicit instruction reduces waste.

Codex respects `-s read-only` reliably — no prefix needed.

## Reporting back to the user

After every consultation, give a brief report. The state of consultants invoked is **non-optional** — the user (and the scorecard, in dual cases) needs to know what actually ran.

- **Single call (mid-iteration Codex):** "Asked Codex about X. It said Y. I agree / I disagree because Z."
- **Dual final-pass:** "Asked both about X. Codex: Y₁. Gemini: Y₂. Convergence on A, B; divergence on C — taking Codex's view because [reason] / escalating C to user."
- **Codex-only-plus-Plan final-pass (Gemini not configured):** "Asked Codex and Plan-subagent about X. Codex said Y₁. Plan-subagent said Y₂. Convergence on A; divergence on B — [synthesis]. **Gemini SKIPPED (not configured on this host); Plan-subagent compensating as second voice.**"
- **Triple final-pass (all three available, Plan-subagent as bonus):** "Asked all three about X. Codex: Y₁. Gemini: Y₂. Plan-subagent: Y₃. [Synthesis: convergence/divergence; tie-breaks resolved by Plan-subagent if Codex↔Gemini split; final decision.]"
- **Codex unreachable, Plan-subagent replacing:** "Codex unreachable (`/tmp/codex_stderr.log`: <reason>); Plan-subagent took over as primary architecture reviewer for this pass. Gemini ran in parallel. Report: Plan-subagent: Y₁. Gemini: Y₂. [Synthesis.]"
- **Gemini drifting, Plan-subagent replacing:** "Gemini answer flagged as drifted (referenced nonexistent files / wrong phase); ignored. Plan-subagent replaced its slot for this pass. Report: Codex: Y₁. Plan-subagent: Y₂. [Synthesis.]"
- **On failure (configured but unreachable):** For Codex: as above (Plan-subagent replaces). For Gemini: same pattern. For Plan-subagent itself: rare; treat as architectural decision — continue with whoever's left and note in report.

The `Gemini SKIPPED` line is the disclosure cost of Codex-only mode. Don't bury it; surface it explicitly so future-you and the user can audit when single-pass discipline was used.

## Scorecard (dual cases only)

When a consultation invoked **both** consultants on a mandatory item or tie-break, append a row to `.agent/consultant_scorecard.md` (schema is in that file's header). Single-consultant calls (including Codex-only final-passes) are not logged in the scorecard — that file is purely for calibrating the two models against each other when both ran.

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
| Codex 429 / rate-limited mid-task | Provider rate limit | Switch to Plan-subagent for this pass; note in report ("Codex rate-limited; Plan-subagent took the primary slot"). Resume Codex on next pass if quota recovers. |
| Gemini drift (answers reference nonexistent files / wrong project phase) | Stale session context, session contamination | Discard the answer; engage Plan-subagent as replacement for this pass; flag for re-priming the Gemini session at next opportunity. Don't try to "fix the answer" — fresh context wins. |
| Consultant fully unreachable (network/quota) | Outage | Continue with remaining consultants (Plan-subagent always available); mark in report. Don't block. |

## Don't block

If a consultant is unreachable or returns an unclear answer, **continue independently** and note it in the report. The skill is a quality lever, not a hard gate. The two hard rules are:

1. Don't claim the dual final-pass happened when it didn't.
2. When in Codex-only mode (Gemini wrapper absent), the `Gemini SKIPPED (not configured on this host)` disclosure line in every report is non-negotiable — that's the cost of operating with reduced discipline.

## Red flags — STOP and reconsider

- About to commit a final spec/plan without running Gemini **when `tools/ask_gemini.sh` exists**
- Thinking "Codex already said yes, no point asking Gemini"
- Thinking "user told me to skip — they decided"
- Running dual sequentially instead of parallel
- Skipping the Gemini read-only prefix
- About to consult on a naming/style/wording choice
- Reporting a Codex-only final-pass without the `Gemini SKIPPED` disclosure line
- Considering "I'll just delete `tools/ask_gemini.sh` from this project to escape dual-pass" — that's policy laundering, observable in git diff
- Picking a winner on Codex↔Gemini tie-break without engaging Plan-subagent
- Treating Plan-subagent as "the cheap option" and bulk-using it in place of Codex for iter-1..N-1 architecture work — its strength is fresh context, not architectural depth; wrong tool for that slot
- Skipping the mandatory final-pass agent-execution question because "the architecture is obviously fine"

Each of these means: stop, run the canonical flow.

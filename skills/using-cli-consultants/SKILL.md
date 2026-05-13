---
name: using-cli-consultants
description: Use when about to draft an architecture/design spec, write or finalize an implementation plan, verify an implementation against its spec, or facing a non-trivial architecture/design judgment call. Skip for trivial naming/wording/style choices that belong to the user. Requires `tools/ask_codex.sh` in the project; `tools/ask_gemini.sh` is optional. Plan-subagent (via Claude Code Agent tool) is **mandatory on every final-pass** in Full mode (when all three are configured), and serves as the mandatory replacement for any unreachable consultant. If wrappers missing, see setting-up-cli-consultants.
---

# Using CLI Consultants

## Overview

Three independent reviewers, each with different blind spots:

- `tools/ask_codex.sh` — **Codex** (primary architecture/design reviewer; **required**)
- `tools/ask_gemini.sh` — **Gemini** (second-opinion reviewer for final passes; **optional**, may be absent on some hosts)
- **Plan-subagent** — Claude Code's `Agent` tool with `subagent_type=Plan, model=opus`; **always available** in any Claude Code session; **mandatory on every final-pass in Full mode** (when Codex + Gemini are both configured) and **mandatory replacement** for any unreachable CLI consultant

Codex and Gemini run as **read-only persistent CLI sessions** that know the project. Plan-subagent is different: **fresh context per call** (no accumulated review history), no rate-limit, no **persistent-session** context-drift, but pays the cost of re-loading orienting context every call. Note: "no persistent-session drift" does NOT mean "no drift at all" — Plan-subagent can still drift on a given call via thin/wrong prompt, missing critical files in the grep list, or wrong-artifact priming. Treat Plan-subagent answers with the same scrutiny as Codex/Gemini answers; see "Plan-subagent drift" in failure modes. The three together catch a wider class of bugs than any pair — Plan-subagent specifically catches execution-readiness issues (broken indentation after iterative edits, fictional API refs, wire-shape gaps) that persistent-context reviewers systematically miss because they accumulate "we already discussed this" bias.

When only Codex is configured (Gemini wrapper absent), Plan-subagent acts as the second voice in **Codex-only-plus-Plan mode** — see below. Pure single-consultant mode is no longer the default fallback; if Codex is also down, escalate to the user.

**v2.0 change vs v1.x:** Plan-subagent on final-pass moved from optional-bonus to mandatory in Full mode. **Final-pass in Full mode dispatches THREE consultants — Codex + Gemini + Plan-subagent — not two.** The discipline cost (one extra Agent-tool call per final-pass) is the explicit trade for catching execution-readiness bugs that two-model review misses. If your mental model is still saying "dual final-pass", that's v1.x carryover — drop it.

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
- `GEMINI_AVAILABLE=0` → **Codex-only-plus-Plan mode** (see below). The Full-mode triple final-pass degrades to a Codex + Plan-subagent quasi-dual pass with a softer mandatory disclosure line.
- All three available → **Full mode** with mandatory triple final-pass. Every spec/plan/impl-verify final-pass dispatches Codex + Gemini + Plan-subagent in parallel. No dual-without-Plan-subagent variant exists in Full mode v2.0+.

## Policy table — when each is mandatory

> **Cardinality reminder:** When a row marks `mandatory (parallel)` for **all three** columns (Codex, Gemini, Plan-subagent), this means a **TRIPLE** dispatch — three consultants firing concurrently in the same orchestration turn. Not two-of-three. Not "Codex+Gemini with Plan-subagent as bonus". Three. If your reading of the row produces a dual or any-two answer, you're applying v1.x mental model — re-read.

> **What "final-pass" means:** A final-pass is a **separate dispatch event** on the artifact that's about to be declared ready. It is NOT the last iter-N. The final spec/plan text — whatever it is at the moment you're about to ship — gets re-read by all mandated consultants from scratch. "Codex already signed off on iter-3" does NOT satisfy Codex's final-pass slot — iter-3 reviewed iter-3's text, and the final draft may differ even by one paragraph. Final-pass is a re-dispatch on the final artifact for ALL mandated channels, including Codex.

| Situation | Codex | Gemini (if configured) | Plan-subagent |
|---|---|---|---|
| Quick architecture sanity-check / design clarification | mandatory | optional | optional |
| Spec draft — iterations 1..N-1 | mandatory | not needed | optional |
| **Spec — final pass (before declaring it ready)** | **mandatory** | **mandatory (parallel)** | **mandatory (parallel)** |
| Plan draft — iterations 1..N-1 | mandatory | not needed | optional |
| **Plan — final pass (before implementation)** | **mandatory** | **mandatory (parallel)** | **mandatory (parallel)** |
| **Verify implementation against spec/plan** | **mandatory** | **mandatory (parallel)** | **mandatory (parallel)** |
| Tie-break on Codex/Gemini disagreement | engage both iteratively until convergence | | **mandatory deciding voice** |
| **Codex rate-limited / unreachable** | n/a | works | **mandatory replacement** |
| **Gemini drifting** (answering about a different phase / referencing nonexistent files) | works | ignore answer | **mandatory replacement** |

**Codex-only-plus-Plan mode (when `tools/ask_gemini.sh` is absent but Plan-subagent is available):** Plan-subagent was already mandatory in this mode in v1.x, so v2.0 changes nothing here — Codex + Plan-subagent quasi-dual pass with the disclosure line `Gemini SKIPPED (not configured on this host); Plan-subagent compensating as second voice`. The v2.0 symmetry is that Plan-subagent is now mandatory in **both** modes, not just this one.

**Don't overuse.** Trivial choices (variable naming, wording, formatting, single-line code style) go to the user directly, never to consultants — including Plan-subagent.

## The discipline this skill enforces

**Final-pass discipline is mandatory regardless of how confident Codex is, how many rounds you ran, or how solid the artifact looks.** In Full mode (v2.0+) that means **triple-mandatory** — Codex + Gemini + Plan-subagent in parallel. Gemini and Plan-subagent are *different* reviewers with *different* blind spots — not rehashes. The triple pass costs ~10 minutes plus one Agent-tool call; missing a load-bearing failure mode costs weeks.

### Rationalizations — STOP if you think any of these

| Excuse | Reality |
|---|---|
| "Codex already signed off twice — Gemini would just rehash" | Gemini is a *different model*. Plan-subagent is a *third different reviewer* with fresh context. If they always agreed, the triple pass would be pointless — the value is in their divergence on the same artifact. |
| "Plan looks solid, covers everything" | "Looks solid" is exactly when blind spots hide. That's the case triple-mandatory final-pass is built for. |
| "We're past the design phase / have momentum" | Sunk cost is not an argument. The cost of one final-pass dispatch (one Gemini call + one Plan-subagent call) is 10 minutes; the cost of a missed failure mode is the rest of the quarter. |
| "User told me to skip the extra round" | The user owns scope and priority; the consultant policy is your discipline, not theirs to waive. State the cost of skipping and run the triple anyway, or explicitly escalate ("policy says triple-mandatory final-pass — skip on your call?"). Do not silently comply. |
| "Time pressure" | Unless the deadline is < 15 min away, the triple-mandatory final-pass fits. If it truly doesn't, run Codex final + flag in the report exactly which consultants were deferred and why. |
| "Trivial change to a final artifact" | If it's trivial, the triple pass returns "no concerns" in 2 minutes. Run it anyway — the cost asymmetry is overwhelming. |
| "Gemini wrapper exists but I'll claim it doesn't to skip" | Lying about environment to escape policy is the discipline failure the skill exists to prevent. The runtime check `[ -x tools/ask_gemini.sh ]` is the ground truth, not your assertion. |
| "I'll just skip installing Gemini in this project to avoid dual final-pass" | Codex-only mode is a cost paid in disclosure (every report carries `Gemini SKIPPED`). Choosing it deliberately to escape discipline is observable in the scorecard and report trail. The right move when Gemini is genuinely unavailable: accept Codex-only and disclose. The wrong move: install-skip as policy laundering. |
| "Reports don't really need the `Gemini SKIPPED` line, the user can see Gemini isn't installed" | Wrong. The disclosure is non-optional in Codex-only mode. It's how you and the user track when single-pass was used vs. dual, for retrospective calibration of misses. |
| "Plan-subagent is optional, so I'll skip it on tie-break to save tokens" | Tie-break is one of the two cases where Plan-subagent is **mandatory**, not optional. Picking a winner between two confidently-disagreeing models without a fresh-context third voice is exactly the failure mode this role exists to prevent. |
| "Codex came back 429, I'll just proceed with Gemini alone and disclose later" | When Codex is unreachable, Plan-subagent is the mandatory replacement, not Gemini-alone. Skipping it forfeits the independent voice the policy requires. Disclose Codex-was-down AND that Plan-subagent took over. |
| "Plan-subagent was the optional bonus voice in v1.x — I'll skip it on this final-pass to save tokens" | v2.0 promoted Plan-subagent to **mandatory** on every final-pass in Full mode. The "optional bonus" framing belongs to v1.x and is no longer valid. Token cost is the explicit trade for catching execution-readiness bugs (UnboundLocalError, deadlocks, undefined helpers, broken indentation after iterative edits) that the two persistent-context reviewers miss. Running it is non-negotiable in Full mode. |
| "Codex already did iter-3 with sign-off, so its final-pass contribution is in hand — I only need to dispatch Gemini and Plan-subagent now" | Final-pass is a **separate dispatch event** from iter-N (see policy-table callout). It re-reads the artifact in its current shape — which may differ from iter-3's text. Codex's iter-3 sign-off is for iter-3's text, not the final draft. Re-dispatch Codex on the final draft alongside Gemini and Plan-subagent. Triple in Full mode means three calls on the final artifact, period. |
| "I'll just dispatch any-two-of-three on final-pass and call it 2-of-3" | Scorecard's "2-of-3 trigger" describes which consultations get LOGGED, not which get DISPATCHED. In Full mode, ALL three must be dispatched. The 2-of-3 trigger handles degraded modes (Codex-only-plus-Plan, or one consultant being unreachable) — not as an opt-out from triple in Full mode. |

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

### Final-pass dispatch — mode-dependent (v2.0)

Detect what's available:

```bash
[ -x tools/ask_gemini.sh ] && GEMINI_AVAILABLE=1 || GEMINI_AVAILABLE=0
# Plan-subagent: always available in Claude Code sessions (Agent tool present).
```

#### Full mode (Codex + Gemini + Plan-subagent) — TRIPLE-MANDATORY, canonical v2.0 pattern

**There is NO dual final-pass in Full mode v2.0+.** All three consultants dispatched in parallel in the SAME orchestration turn.

```bash
# Compose question files (usually identical or near-identical)
cat > /tmp/codex_question.txt  <<'EOF' ...
cat > /tmp/gemini_question.txt <<'EOF' ...

# In the SAME assistant message:
#   (a) fire BOTH bash wrappers in the background
#   (b) dispatch Plan-subagent as an Agent tool call (subagent_type=Plan, model=opus)
#       with the PLAN_SUBAGENT_PROMPT.md scaffold.
# The agent runtime parallelizes natively across tool types.
./tools/ask_codex.sh  > /tmp/codex_run.log  2>&1 &
./tools/ask_gemini.sh > /tmp/gemini_run.log 2>&1 &
wait  # for bash backgrounds; Plan-subagent's reply arrives via Agent tool result

# Synthesize ALL THREE answers. Report triple convergence/divergence.
```

If you find yourself dispatching only two of three in Full mode, **STOP** — you've fallen back to the v1.x dual mental model. Re-read the policy table and re-dispatch the missing third channel.

#### Codex-only-plus-Plan mode (Gemini wrapper absent) — quasi-dual

```bash
cat > /tmp/codex_question.txt <<'EOF' ...

# In the SAME message: fire ask_codex.sh + dispatch Plan-subagent via Agent tool.
./tools/ask_codex.sh > /tmp/codex_run.log 2>&1 &
wait
```

Report MUST include disclosure: **`Gemini SKIPPED (not configured on this host); Plan-subagent compensating as second voice.`**

#### Pure-Codex fallback (Plan-subagent unreachable — rare)

Only when the runtime has no Agent tool (e.g., direct CLI Codex/Gemini session, not Claude Code):

```bash
cat > /tmp/codex_question.txt <<'EOF' ...
./tools/ask_codex.sh
```

Report MUST include disclosure: **`Plan-subagent UNAVAILABLE (no Agent tool in this runtime — degraded to v1.x dual or pure-Codex for this pass)`**. Surface to the user — the operational skill expects an Agent-tool-bearing environment.

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

**Parallel triple final-pass — the canonical Full-mode pattern (v2.0):**

In Full mode (all three consultants configured), every spec/plan/impl-verify final-pass MUST dispatch all three in parallel. "Parallel" here means **same-orchestration-turn dispatch**: one assistant message that fires both bash wrappers in the background AND issues the Agent tool call for Plan-subagent. The agent runtime parallelizes natively across tool types.

```bash
# Fire CLI consultants in parallel
./tools/ask_codex.sh  > /tmp/codex_run.log  2>&1 &
./tools/ask_gemini.sh > /tmp/gemini_run.log 2>&1 &
# In the SAME message: dispatch Plan-subagent as an Agent tool call with the
# PLAN_SUBAGENT_PROMPT.md template content. Both wrappers and Agent run concurrently.
wait  # for the bash backgrounds
# Plan-subagent completion is signaled by the Agent tool result in the same turn.
# Synthesize all three answers; report triple convergence/divergence.
```

**Sequential dispatch is not the canonical pattern** — it wastes wall-clock and starves the parallelism that justifies the triple cost. If for some reason Plan-subagent cannot be dispatched in the same turn (e.g., the wrapper outputs need to be inspected before deciding what to ask Plan-subagent — rare), explicitly note in the consultation report that the pass was serial, not parallel.

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
- **Full-mode triple final-pass (v2.0 canonical pattern, all three available):** "Triple final-pass on X. Codex: Y₁. Gemini: Y₂. Plan-subagent: Y₃. [Synthesis: convergence/divergence per finding; tie-breaks within the triple resolved by majority or escalated to user when non-falsifiable; final decision.]"
- **Codex-only-plus-Plan final-pass (Gemini not configured):** "Asked Codex and Plan-subagent about X. Codex said Y₁. Plan-subagent said Y₂. Convergence on A; divergence on B — [synthesis]. **Gemini SKIPPED (not configured on this host); Plan-subagent compensating as second voice.**"
- **Dual-only fallback (rare — Plan-subagent unavailable in this runtime):** "Codex + Gemini dual final-pass. Plan-subagent UNAVAILABLE (no Agent tool in this runtime — degraded to v1.x dual policy for this pass)." This indicates the agent isn't running inside Claude Code or an equivalent Agent-tool-bearing runtime; surface to the user.
- **Codex unreachable, Plan-subagent replacing:** "Codex unreachable (`/tmp/codex_stderr.log`: <reason>); Plan-subagent took over as primary architecture reviewer for this pass. Gemini ran in parallel. Report: Plan-subagent: Y₁. Gemini: Y₂. [Synthesis.]"
- **Gemini drifting, Plan-subagent replacing:** "Gemini answer flagged as drifted (referenced nonexistent files / wrong phase); ignored. Plan-subagent replaced its slot for this pass. Report: Codex: Y₁. Plan-subagent: Y₂. [Synthesis.]"
- **On failure (configured but unreachable):** For Codex: as above (Plan-subagent replaces). For Gemini: same pattern. For Plan-subagent itself: rare; treat as architectural decision — continue with whoever's left and note in report.

The `Gemini SKIPPED` line is the disclosure cost of Codex-only mode. Don't bury it; surface it explicitly so future-you and the user can audit when single-pass discipline was used.

## Scorecard (multi-consultant cases)

When a consultation invoked **at least 2 of 3** consultants on the same question, append a row to `.agent/consultant_scorecard.md` (schema is in that file's header). In Full mode v2.0+, every spec/plan/impl-verify final-pass triggers a row (all three engaged); in Codex-only-plus-Plan mode, every final-pass also triggers a row (Codex + Plan-subagent = 2 of 3). Single-consultant iter-1..N-1 calls are NOT logged — the scorecard is for calibrating models against each other when more than one ran.

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
| Plan-subagent drift (answers wrong-artifact, references files not in grep-list, addresses wrong review phase, hallucinates BLOCKERs that don't match the actual code) | Thin/wrong prompt; missing critical-files-to-grep list; wrong commit-SHA/version reference in prompt; subagent took shortcuts | Discard the answer. Re-dispatch with a TIGHTER prompt: explicit commit SHA, exact paths in grep list, the actual artifact text quoted inline. If second dispatch also drifts, escalate to user — the prompt template needs rework. Don't paper over with "Plan-subagent had no context" rationalization. |
| Consultant fully unreachable (network/quota) | Outage | Continue with remaining consultants (Plan-subagent always available in Claude Code sessions); mark in report. Don't block. |
| Plan-subagent unavailable (no Agent tool in runtime) | Running outside Claude Code (e.g., direct CLI Codex/Gemini session, or another agent runtime) | Degrade to v1.x dual policy for this final-pass; explicit disclosure line `Plan-subagent UNAVAILABLE (no Agent tool in this runtime)` in the report. Surface to user — this likely means the operational skill is being executed in the wrong environment. |

## Don't block

If a consultant is unreachable or returns an unclear answer, **continue independently** and note it in the report. The skill is a quality lever, not a hard gate. The two hard rules are:

1. Don't claim the final-pass happened in a mode it didn't (triple in Full, quasi-dual in Codex-only-plus-Plan).
2. When in Codex-only-plus-Plan mode (Gemini wrapper absent), the `Gemini SKIPPED (not configured on this host); Plan-subagent compensating as second voice` disclosure line in every report is non-negotiable — that's the cost of operating without Gemini.

## Red flags — STOP and reconsider

- About to commit a final spec/plan without running Gemini **when `tools/ask_gemini.sh` exists**
- Thinking "Codex already said yes, no point asking Gemini"
- Thinking "user told me to skip — they decided"
- Running the final-pass sequentially instead of dispatching all available consultants in the same orchestration turn
- Skipping the Gemini read-only prefix
- About to consult on a naming/style/wording choice
- Reporting a Codex-only final-pass without the `Gemini SKIPPED` disclosure line
- Considering "I'll just delete `tools/ask_gemini.sh` from this project to escape dual-pass" — that's policy laundering, observable in git diff
- Picking a winner on Codex↔Gemini tie-break without engaging Plan-subagent
- Treating Plan-subagent as "the cheap option" and bulk-using it in place of Codex for iter-1..N-1 architecture work — its strength is fresh context, not architectural depth; wrong tool for that slot
- Skipping the mandatory final-pass agent-execution question because "the architecture is obviously fine"
- About to commit a final spec/plan in Full mode without dispatching Plan-subagent — this was acceptable in v1.x but is a v2.0 policy violation
- Treating "triple final-pass" as the v1.x "dual final-pass with Plan-subagent bonus" — they have different mandatoriness, and reporting must reflect the v2.0 pattern

Each of these means: stop, run the canonical flow.

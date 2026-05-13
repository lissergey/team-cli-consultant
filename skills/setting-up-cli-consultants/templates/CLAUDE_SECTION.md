## CLI Consultants (Codex + optional Gemini + Plan-subagent)

This project uses three potential reviewers — two read-only persistent CLI sessions plus an in-session fresh-context subagent.

- `tools/ask_codex.sh` — **Codex** (primary reviewer; **required**)
- `tools/ask_gemini.sh` — **Gemini** (second-opinion on final passes; **optional**, may be absent on some hosts)
- **Plan-subagent** — Claude Code's `Agent` tool with `subagent_type=Plan, model=opus`; **always available** in any Claude Code session; **mandatory (parallel) on every final-pass in Full mode** and **mandatory replacement** when Codex is rate-limited or Gemini is drifting

Mechanism for Codex/Gemini: write the question to `/tmp/codex_question.txt` (or `/tmp/gemini_question.txt`), run the script, read the answer from `/tmp/codex_answer.txt` (or `/tmp/gemini_answer.txt`). Both can read the live repo and cite file paths, but cannot edit anything.

Mechanism for Plan-subagent: one self-contained `Agent` tool call per consultation; no `/tmp/` files. Prompt scaffold lives at `${CLAUDE_PLUGIN_ROOT}/skills/setting-up-cli-consultants/templates/PLAN_SUBAGENT_PROMPT.md`.

The agent detects what's available at consultation time:

```bash
[ -x tools/ask_codex.sh ]  && CODEX_AVAILABLE=1  || CODEX_AVAILABLE=0
[ -x tools/ask_gemini.sh ] && GEMINI_AVAILABLE=1 || GEMINI_AVAILABLE=0
# Plan-subagent: always 1 in any Claude Code session with Agent tool.
PLAN_SUBAGENT_AVAILABLE=1
```

### When each is mandatory

| Situation | Codex | Gemini (if `GEMINI_AVAILABLE=1`) | Plan-subagent |
|---|---|---|---|
| Quick architecture sanity-check | mandatory | optional | optional |
| Spec — iterations 1..N-1 | mandatory | not needed | optional |
| **Spec — final pass (before declaring it ready)** | **mandatory** | **mandatory (parallel)** | **mandatory (parallel)** |
| Plan — iterations 1..N-1 | mandatory | not needed | optional |
| **Plan — final pass (before implementation)** | **mandatory** | **mandatory (parallel)** | **mandatory (parallel)** |
| **Verify implementation against spec/plan** | **mandatory** | **mandatory (parallel)** | **mandatory (parallel)** |
| Tie-break on Codex/Gemini disagreement | engage both iteratively until convergence | | **mandatory deciding voice** |
| **Codex rate-limited / unreachable** | n/a | works | **mandatory replacement** |
| **Gemini drifting** | works | ignore answer | **mandatory replacement** |

**Codex-only-plus-Plan mode (when `tools/ask_gemini.sh` is absent):** every "mandatory dual" cell above degrades to a Codex + Plan-subagent quasi-dual pass with a **non-optional `Gemini SKIPPED (not configured on this host); Plan-subagent compensating as second voice`** disclosure line in the consultation report. The discipline does not vanish — Plan-subagent's fresh-context first-read covers most of what Gemini would have caught.

### Rules

- **Consultant first, user second.** Architecture/design/planning questions go to consultants BEFORE the user. Saves the user's time.
- **Don't overuse.** Trivial choices (variable naming, wording, formatting) go to the user directly, never to consultants.
- **Final pass in Full mode = Codex + Gemini + Plan-subagent in parallel (triple-mandatory v2.0).** In Codex-only-plus-Plan mode (Gemini missing) it remains Codex + Plan-subagent dual with the `Gemini SKIPPED` disclosure. Plan-subagent's role moved from optional bonus (v1.x) to mandatory (v2.0+) in both modes. Sequential dispatch is not the canonical pattern — fire all available consultants in the same orchestration turn.
- **Final-pass prompts MUST include the agent-execution question:** *"Would a fresh subagent with no prior context execute this spec/plan correctly on first try, without UnboundLocalErrors, deadlocks, missing variable references, or undefined helpers? Are all task boundaries self-contained?"*
- **Don't block.** If a consultant is unreachable or unclear, continue independently and note it in the report.
- **Report briefly after each consultation:** what asked, what got, agree/disagree. On dual: convergence vs. divergence. In Codex-only mode: include the `Gemini SKIPPED (not configured on this host)` disclosure line every time.
- **Scorecard.** Calls with **at least 2 of 3 consultants engaged** on the same question append a row to `.agent/consultant_scorecard.md`. In Full mode this is every spec/plan/impl-verify final-pass (all three engaged); in Codex-only-plus-Plan mode it is every final-pass (Codex + Plan-subagent = 2 of 3). Single-consultant iter-1..N-1 calls are not logged. See `using-cli-consultants` for full v2.0 schema.

### Operational details

For invocation patterns, prompt structure, the required Gemini read-only prefix, parallel-pass commands, failure modes, and the discipline rationale (especially against sunk-cost / authority pressure to skip the dual final-pass), see the `using-cli-consultants` skill.

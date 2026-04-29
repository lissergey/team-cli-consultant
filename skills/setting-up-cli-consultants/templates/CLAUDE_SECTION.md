## CLI Consultants (Codex + optional Gemini)

This project uses CLI consultants as read-only architecture/design reviewers. They run as persistent sessions preloaded with project context. The agent invokes them via file-based wrapper scripts.

- `tools/ask_codex.sh` — **Codex** (primary reviewer; **required**)
- `tools/ask_gemini.sh` — **Gemini** (second-opinion on final passes; **optional**, may be absent on some hosts)

Mechanism: write the question to `/tmp/codex_question.txt` (or `/tmp/gemini_question.txt`), run the script, read the answer from `/tmp/codex_answer.txt` (or `/tmp/gemini_answer.txt`). Both consultants can read the live repo and cite file paths, but cannot edit anything.

The agent detects which wrappers are present at consultation time:

```bash
[ -x tools/ask_codex.sh ]  && CODEX_AVAILABLE=1  || CODEX_AVAILABLE=0
[ -x tools/ask_gemini.sh ] && GEMINI_AVAILABLE=1 || GEMINI_AVAILABLE=0
```

### When each is mandatory

| Situation | Codex | Gemini (if `GEMINI_AVAILABLE=1`) |
|---|---|---|
| Quick architecture sanity-check | mandatory | optional |
| Spec — iterations 1..N-1 | mandatory | not needed |
| **Spec — final pass (before declaring it ready)** | **mandatory** | **mandatory (parallel)** |
| Plan — iterations 1..N-1 | mandatory | not needed |
| **Plan — final pass (before implementation)** | **mandatory** | **mandatory (parallel)** |
| **Verify implementation against spec/plan** | **mandatory** | **mandatory (parallel)** |
| Tie-break on disagreement | engage both iteratively until convergence | |

**Codex-only mode (when `tools/ask_gemini.sh` is absent):** every "mandatory dual" cell above degrades to a single-Codex pass with a **non-optional `Gemini SKIPPED (not configured on this host)`** disclosure line in the consultation report. The discipline does not vanish — it gets demoted into single-pass-with-disclosure.

### Rules

- **Consultant first, user second.** Architecture/design/planning questions go to consultants BEFORE the user. Saves the user's time.
- **Don't overuse.** Trivial choices (variable naming, wording, formatting) go to the user directly, never to consultants.
- **Final pass = both, in parallel — IF `tools/ask_gemini.sh` exists.** Not sequentially. Even if Codex already approved across multiple rounds — Gemini is a *different* model with different blind spots, not a rehash. If only Codex is wired up, fall back to single-Codex final-pass with the `Gemini SKIPPED` disclosure line.
- **Don't block.** If a consultant is unreachable or unclear, continue independently and note it in the report.
- **Report briefly after each consultation:** what asked, what got, agree/disagree. On dual: convergence vs. divergence. In Codex-only mode: include the `Gemini SKIPPED (not configured on this host)` disclosure line every time.
- **Scorecard.** Dual-consultant calls (mandatory items or tie-breaks) append a row to `.agent/consultant_scorecard.md`. Single calls (including Codex-only final-passes) are not logged — the scorecard is purely for calibrating the two models against each other when both ran.

### Operational details

For invocation patterns, prompt structure, the required Gemini read-only prefix, parallel-pass commands, failure modes, and the discipline rationale (especially against sunk-cost / authority pressure to skip the dual final-pass), see the `using-cli-consultants` skill.

## CLI Consultants (Codex + Gemini)

This project uses two CLI consultants as read-only architecture/design reviewers. Both run as persistent sessions preloaded with project context. The agent invokes them via file-based wrapper scripts.

- `tools/ask_codex.sh` — **Codex** (primary reviewer)
- `tools/ask_gemini.sh` — **Gemini** (second-opinion on final passes)

Mechanism: write the question to `/tmp/codex_question.txt` (or `/tmp/gemini_question.txt`), run the script, read the answer from `/tmp/codex_answer.txt` (or `/tmp/gemini_answer.txt`). Both consultants can read the live repo and cite file paths, but cannot edit anything.

### When each is mandatory

| Situation | Codex | Gemini |
|---|---|---|
| Quick architecture sanity-check | mandatory | optional |
| Spec — iterations 1..N-1 | mandatory | not needed |
| **Spec — final pass (before declaring it ready)** | **mandatory** | **mandatory (parallel)** |
| Plan — iterations 1..N-1 | mandatory | not needed |
| **Plan — final pass (before implementation)** | **mandatory** | **mandatory (parallel)** |
| **Verify implementation against spec/plan** | **mandatory** | **mandatory (parallel)** |
| Tie-break on disagreement | engage both iteratively until convergence | |

### Rules

- **Consultant first, user second.** Architecture/design/planning questions go to consultants BEFORE the user. Saves the user's time.
- **Don't overuse.** Trivial choices (variable naming, wording, formatting) go to the user directly, never to consultants.
- **Final pass = both, in parallel.** Not sequentially. Even if Codex already approved across multiple rounds — Gemini is a *different* model with different blind spots, not a rehash.
- **Don't block.** If a consultant is unreachable or unclear, continue independently and note it in the report.
- **Report briefly after each consultation:** what asked, what got, agree/disagree; on dual: convergence vs. divergence.
- **Scorecard.** Dual-consultant calls (mandatory items or tie-breaks) append a row to `.agent/consultant_scorecard.md`. Single calls are not logged.

### Operational details

For invocation patterns, prompt structure, the required Gemini read-only prefix, parallel-pass commands, failure modes, and the discipline rationale (especially against sunk-cost / authority pressure to skip the dual final-pass), see the `using-cli-consultants` skill.

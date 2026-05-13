# Consultant Scorecard

Tracks Codex / Gemini / Plan-subagent accuracy across multi-consultant calls. Used to calibrate which consultant to trust on which task type over time.

**Schema version:** v2.0 (introduced in plugin v2.0.0; v1.x rows with the old 11-column schema may coexist below — agent tolerates mixed history).

## When to fill in

Append a row when **at least 2 of 3** consultants were engaged on the same question. In Full mode v2.0+, every spec/plan/impl-verify final-pass triggers a row (since Plan-subagent is mandatory alongside Codex + Gemini). In Codex-only-plus-Plan mode, every final-pass also triggers a row (Codex + Plan-subagent = 2 of 3). Single-consultant calls (e.g., Codex on iter-1..N-1 of a spec) are NOT logged.

## Schema (v2.0)

| Column | Values / examples |
|---|---|
| `date` | YYYY-MM-DD |
| `artifact` | path to the discussed file/spec, or short project ID |
| `task_type` | `spec` / `plan` / `impl-check` / `architecture` / `bug-analysis` / `policy` |
| `question` | one-line gist |
| `codex_tldr` | 1–2 lines — Codex's answer summary |
| `gemini_tldr` | 1–2 lines — Gemini's answer summary (or `SKIPPED (not configured)` in Codex-only-plus-Plan mode) |
| `plan_subagent_tldr` | 1–2 lines — Plan-subagent's answer summary |
| `codex_eval` | `correct` / `partial` / `wrong` / `irrelevant` / `timeout` / `skipped` |
| `gemini_eval` | same set |
| `plan_subagent_eval` | same set |
| `winner` | `codex` / `gemini` / `plan_subagent` / `tie` / `all-wrong` |
| `ground_truth` | what was actually true after the fact (`?` if not yet known — revisit later) |
| `notes` | key difference, who missed what, who recalled critical detail |

`eval` is determined by verification against the live code/spec. `winner` weighs completeness, insight value, and file:line citation accuracy — not just `eval` rank.

## Entries

<!-- Append new rows below this line. -->

| date | artifact | task_type | question | codex_tldr | gemini_tldr | plan_subagent_tldr | codex_eval | gemini_eval | plan_subagent_eval | winner | ground_truth | notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|

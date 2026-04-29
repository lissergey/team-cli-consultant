# Consultant Scorecard

Tracks Codex vs. Gemini accuracy across dual-consultant calls. Used to calibrate which consultant to trust on which task type over time.

## When to fill in

Append a row when a consultation invoked **both** consultants on the same question — i.e., mandatory dual cases per the CLAUDE.md policy table (spec/plan final pass, impl verification) or tie-break rounds. Single-consultant calls are NOT logged here.

## Schema

| Column | Values / examples |
|---|---|
| `date` | YYYY-MM-DD |
| `artifact` | path to the discussed file/spec, or short project ID |
| `task_type` | `spec` / `plan` / `impl-check` / `architecture` / `bug-analysis` / `policy` |
| `question` | one-line gist |
| `codex_tldr` | 1–2 lines — Codex's answer summary |
| `gemini_tldr` | 1–2 lines — Gemini's answer summary |
| `codex_eval` | `correct` / `partial` / `wrong` / `irrelevant` / `timeout` |
| `gemini_eval` | same set |
| `winner` | `codex` / `gemini` / `tie` / `both-wrong` |
| `ground_truth` | what was actually true after the fact (`?` if not yet known — revisit later) |
| `notes` | key difference, who missed what, who recalled critical detail |

`eval` is determined by verification against the live code/spec. `winner` is not strictly `max(codex_eval, gemini_eval)` — also weighs completeness, insight value, and file:line citation accuracy.

## Entries

<!-- Append new rows below this line. -->

| date | artifact | task_type | question | codex_tldr | gemini_tldr | codex_eval | gemini_eval | winner | ground_truth | notes |
|---|---|---|---|---|---|---|---|---|---|---|

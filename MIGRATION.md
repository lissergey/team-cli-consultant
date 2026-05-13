# Migration Guide — v1.x → v2.0

cli-consultants v2.0 is a **breaking policy change**. Existing v1.x setups continue to work without errors, but the operational discipline expected of the agent has changed. Read this before bumping installations.

## What changed

### 1. Plan-subagent is mandatory on final-pass (Full mode)

| Mode | v1.x final-pass | v2.0 final-pass |
|---|---|---|
| Full (Codex + Gemini configured) | Codex + Gemini dual; Plan-subagent optional bonus | Codex + Gemini + Plan-subagent **triple-mandatory** in parallel |
| Codex-only-plus-Plan (Gemini absent) | Codex + Plan-subagent dual with disclosure | Same — unchanged |

The rationalization "Plan-subagent is the optional bonus voice, I'll skip it to save tokens" is no longer valid; it's now in the rationalization-counter table.

### 2. Scorecard schema bump

`consultant_scorecard.md` template gains three columns:

- `plan_subagent_tldr`
- `plan_subagent_eval`
- Extended `winner` value set: `codex` / `gemini` / `plan_subagent` / `tie` / `all-wrong`

Trigger description updated: "at least 2 of 3 consultants engaged" (was: "both consultants called").

**Existing scorecard files are not modified.** v2.0 setup-skill detects v1.x schema and leaves the file alone — v2.0 entries append below in the new format. Mixed-schema files are tolerated.

## What did NOT change

- Wrapper scripts (`tools/ask_codex.sh`, `tools/ask_gemini.sh`) — identical to v1.2.0
- `/tmp/{codex,gemini}_{question,answer}.txt` file convention
- Codex sandbox flag (`-s read-only`) and Gemini sandbox flag (`--approval-mode plan`)
- Codex-only-plus-Plan mode mechanics (already had Plan-subagent compensating in v1.2.0)
- Failure modes for Codex 429 / Gemini drift (Plan-subagent was already mandatory replacement)
- Agent-execution question on final-pass (introduced in v1.2.0; still mandatory)

## Action required for existing installations

If your project has `tools/ask_codex.sh` and `tools/ask_gemini.sh` already wired up from v1.x:

1. Update the plugin: `/plugin marketplace update team-cli-consultant` then update via `/plugin` UI or uninstall+install.
2. (Optional) Re-run the `setting-up-cli-consultants` skill — it's idempotent. New install would write the v2.0 scorecard schema and refresh the CLAUDE.md section text.
3. Communicate to teammates: from now on, every final-pass dispatches all three reviewers in parallel.

No wrapper scripts to reinstall, no session re-priming, no auth changes.

## Parked for v2.1

These items from the May 2026 update were **not** included in v2.0:

- Spec categorization → Gemini mandatory on iter-1..N-1 for UX-heavy / build-toolchain / operational-rollout
- `.agent/SCORECARD_INSIGHTS.md` — compressed scorecard patterns companion file

Reasoning: v2.0 ships the structural triple change. Categorization needs a classifier mechanism (path-based / frontmatter / heuristic) that warrants its own brainstorm. INSIGHTS is an operational tool that benefits from real scorecard volume to design well.

## Going back to v1.x

If v2.0 causes friction:

```
/plugin uninstall cli-consultants@team-cli-consultant
# Then add the v1.2.0 marketplace by tag or revert your local cache.
```

We don't have a CLI flag to pin v1.x; downgrade is manual via marketplace.json edit if needed.

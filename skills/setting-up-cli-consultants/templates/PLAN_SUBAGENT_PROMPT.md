<!--
Prompt scaffold for Plan-subagent review calls.

USAGE: Fill in the placeholders, then pass as the `prompt` argument to:
  Agent({ description: "...", subagent_type: "Plan", model: "opus", prompt: <this> })

Plan-subagent has NO conversation history. The prompt must be self-contained.
-->

You are reviewing **<spec-path>** at commit **<sha>** (frontmatter version: **<version>**).

# Background

<2 paragraphs: what this document describes, and what foundation it builds on —
previous phases, related specs, etc. Plan-subagent has no access to the parent
conversation; everything it needs to make sense of the artifact must be here.>

# Review history

<Short summary: how many rounds with which consultants ran, which BLOCKERs were
closed, why fresh eyes are needed now. Example:>

> 3 rounds with Codex (closed BLOCKERs: <A>, <B>), 2 rounds with Gemini
> (closed: <C>). This is the final pass — we need a fresh-context reader who
> hasn't seen the prior iterations.

# Critical files to grep before commenting on claims

<Explicit list of files + approximate line ranges Plan-subagent should inspect
to verify the spec's claims against current code. Save the subagent's time —
don't make it discover the topology. Example:>

- `daemon/api/foo.py:120-200` — the `Foo.process()` method this spec refers to
- `daemon/models/state.py:45-90` — `StateFrame` fields and shape
- `web/control-center/src/sse/schemas.ts` — zod schemas the spec touches

# Your task

Produce numbered findings on:

1. **Architectural coherence** — does the design hang together? Are responsibilities split sensibly?
2. **State machine completeness** — are all transitions covered? Any unreachable states?
3. **Codebase verification** — do the claims match current code? Use the file list above to check.
4. **Scenario coverage** — happy paths, failure modes, race conditions, edge cases.
5. **Forward-prep** — what does this spec set up or constrain for the next phase?
6. **Cross-section consistency** — do the sections of the document agree with each other? Any drift between intro and detail?
7. **Agent-execution check** — **would a fresh subagent with no prior context execute this spec/plan correctly on first try, without UnboundLocalErrors, deadlocks, missing variable references, or undefined helpers? Are all task boundaries self-contained?**

# Output format

Numbered findings, each tagged with severity:

- **BLOCKER** — must fix before ship
- **IMPORTANT** — should fix; surface to author
- **NICE-TO-HAVE** — improvement, not required
- **OK** — explicit confirmations (helpful so the verdict isn't ambiguous)

End with one of three verdicts:

- `ship-as-is` — no BLOCKER, no IMPORTANT
- `fix-then-ship` — only IMPORTANT/NICE-TO-HAVE
- `iter-N needed` — at least one BLOCKER; specify what would change next iteration

# Constraints

Read-only. Do NOT modify any files. If you propose a code change, describe it; don't write it.

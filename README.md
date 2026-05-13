# CLI Consultants — Claude Code plugin

> **v2.0 — BREAKING:** Plan-subagent is now mandatory on every final-pass in Full mode (was optional bonus in v1.x). Scorecard schema bumped to 3 columns. See [MIGRATION.md](./MIGRATION.md) for the upgrade path. Existing scorecard files are left untouched; the policy change is loud-by-design.

Three-channel review flow (Codex + optional Gemini + Plan-subagent) as a Claude Code plugin. Ships two skills:

- **`using-cli-consultants`** — operational policy: when each consultant is mandatory (architecture sanity-checks, spec drafts, plan finalization, impl verification), how to invoke them, dual final-pass discipline against sunk-cost / authority pressure.
- **`setting-up-cli-consultants`** — installs wrapper scripts (`tools/ask_codex.sh`, `tools/ask_gemini.sh`), CLAUDE.md policy section, scorecard, and walks through session priming (Path A manual / Path B semi-automated).

## Install

Once (per teammate):

```
/plugin marketplace add https://github.com/lissergey/team-cli-consultant.git
/plugin install cli-consultants@team-cli-consultant
```

Update later:

```
/plugin marketplace update team-cli-consultant
/plugin install cli-consultants@team-cli-consultant
```

After install, the skills are available as:

- `cli-consultants:using-cli-consultants`
- `cli-consultants:setting-up-cli-consultants`

(Plugin namespace prefix is automatic — these don't collide with personal `~/.claude/skills/<name>/` skills if any teammate has them.)

## Prerequisites on each teammate's machine

The plugin only ships skill content. Each teammate needs to set up their own auth and sessions on their machine. Codex is required; Gemini is optional.

**Required:**
1. **Codex CLI** (`@openai/codex` ≥ 0.117; tested on 0.125) installed via npm under nvm-managed Node ≥ 18.
2. `~/.codex/` auth set up via `codex login`.
3. Per project: a primed Codex session (UUID pasted into `tools/ask_codex.sh`).

**Optional but recommended:**
4. **Gemini CLI** (`@google/gemini-cli` ≥ 0.40 — earlier versions don't support `--approval-mode plan` and use different `--resume` semantics) installed under nvm-managed Node ≥ 20.
5. `~/.gemini/` auth set up (oauth-personal works; the CLI walks you through it interactively).
6. Per project: a primed Gemini session (the wrapper resumes `latest` by default).

**Always available (no install needed):**
7. **Plan-subagent** — invoked via Claude Code's `Agent` tool at consultation time. No CLI, no auth, no session priming. Serves three roles: (a) **mandatory third channel on every final-pass in Full mode (v2.0 — was optional bonus in v1.x)**; (b) mandatory replacement when Codex is rate-limited or Gemini is drifting; (c) compensating second voice in Codex-only-plus-Plan mode.

If Gemini is not installed, the setup skill produces **Codex-only-plus-Plan mode**: `tools/ask_codex.sh` is installed and Plan-subagent fills the second-voice slot on final-pass. The disclosure line in reports becomes `Gemini SKIPPED (not configured on this host); Plan-subagent compensating as second voice` — discipline is preserved through the third channel. Re-running the setup skill after a teammate later installs Gemini upgrades the project to Full mode (idempotent install).

Use the `setting-up-cli-consultants` skill — it handles all of this and detects which mode applies on each teammate's machine.

The skill assumes nvm at `$HOME/.nvm`. If a teammate uses a different Node manager (asdf, fnm), they'll need to adapt the `nvm use` lines in the wrappers — or remove them if Node is system-wide.

## What the skills enforce

- **Don't draft non-trivial architecture/specs/plans without consulting Codex first.**
- **Final-pass on a spec or plan is mandatory TRIPLE (Codex + Gemini + Plan-subagent in parallel) in Full mode (v2.0 change).** Even when Codex already approved across multiple rounds. The skill's whole reason to exist is to hold this line under "Codex already signed off" pressure.
- **In Codex-only-plus-Plan mode** (Gemini wrapper absent), final-pass is Codex + Plan-subagent quasi-dual with a non-optional `Gemini SKIPPED (not configured on this host); Plan-subagent compensating as second voice` disclosure line in every report. Unchanged from v1.2.0.
- **All final-pass prompts MUST include the agent-execution question** (verbatim wording in `skills/using-cli-consultants/SKILL.md`) — catches execution-readiness bugs (UnboundLocalError, deadlocks, undefined helpers) that architectural review misses.
- **Scorecard schema v2.0** adds `plan_subagent_tldr` / `plan_subagent_eval` columns + extended `winner` value set. Existing v1.x scorecards are preserved on re-install (non-destructive upgrade).
- **Don't overuse.** Trivial naming/wording/style choices go to the user, never to consultants.
- **Don't block.** If a consultant is unreachable, continue independently and note it in the report.

Full policy table and rationalization counters live in `skills/using-cli-consultants/SKILL.md`.

## Repo layout

```
.
├── MIGRATION.md             # v1.x → v2.0 breaking-change notes
├── .claude-plugin/
│   ├── plugin.json          # plugin metadata
│   └── marketplace.json     # marketplace listing
├── skills/
│   ├── using-cli-consultants/
│   │   └── SKILL.md         # operational policy
│   └── setting-up-cli-consultants/
│       ├── SKILL.md         # setup procedure
│       └── templates/
│           ├── ask_codex.sh
│           ├── ask_gemini.sh
│           ├── CLAUDE_SECTION.md
│           ├── consultant_scorecard.md
│           └── PLAN_SUBAGENT_PROMPT.md   # prompt scaffold for Plan-subagent calls
└── README.md
```

## Versioning

Bump `version` in both `plugin.json` and `marketplace.json` when you ship breaking changes to the skills or templates. With explicit versions, teammates only update when you bump — `git push` alone doesn't force them. If you omit `version`, every commit becomes a new version (more aggressive update cadence).

## License

MIT.

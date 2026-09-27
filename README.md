# my-agent-skills

Reusable skills for Claude (the Claude app, Cowork and Claude Code). Each skill lives in its own folder under `skills/` with a `SKILL.md` inside, plus optional `references/` and `templates/` the skill points to. Install the whole folder, not just SKILL.md.

## Skills

| Skill | What it does |
| --- | --- |
| [loop-engineering](skills/loop-engineering/SKILL.md) | Plan-first, test-gated build loop for API-first apps: plan, mocks, OpenAPI design and test plans up front, then build each phase, gate it on tests and ship to beta before prod. Defaults to Cloudflare Workers and Pages, Clerk, portable Postgres (Neon or Supabase), R2, Redis, n8n, Stripe and Sentry, and comes with lessons learned from production incidents. |
| [architecture-upgrade](skills/architecture-upgrade/SKILL.md) | Audits an existing app (read only), writes a plain-language architecture page and an evidence-backed gap report, plans fixes in phases within the current stack (beta before prod, API-first, core logic out of n8n, single-server risk), then fixes them with a test-gated loop. Install together with loop-engineering. |

New to this? Read **[GETTING-STARTED.md](GETTING-STARTED.md)**: point Claude at your project, get a plain-language check-up, then upgrade it step by step.

## Quick start: fix an existing app

1. Install both **loop-engineering** and **architecture-upgrade** (steps below).
2. Open your app's repo in Claude Code, or connect its folder in Claude Cowork.
3. Paste:

   > Use the architecture-upgrade skill on this repo. Audit it read only, write docs/architecture.md and the gap report, then give me the phased fix plan and your questions. Do not change anything until I approve the plan.

4. Answer its questions, approve the plan, and it fixes one phase at a time, shipping to beta first and telling you what to try.

## Installing a skill

### Claude app or Cowork

1. Download the ready-made zip for each skill from the [`dist/`](dist) folder (open the file on GitHub, then the download button): `loop-engineering.zip` and `architecture-upgrade.zip`.
2. In Claude, open Settings, find the Skills section and upload each zip.

Maintainers: after changing a skill, run `./scripts/build-zips.sh` and commit the updated `dist/` zips.

### Claude Code

Copy the skill folder into your personal skills directory:

```bash
git clone https://github.com/bilgrami/my-agent-skills.git
cp -r my-agent-skills/skills/loop-engineering my-agent-skills/skills/architecture-upgrade ~/.claude/skills/
```

Or put it in a project's `.claude/skills/` folder to share it with everyone on that repo.

## Customizing

Skills are plain Markdown. Fork the repo or edit `SKILL.md` directly to swap in your own stack, models or rules. The loop-engineering stack rules are labelled as defaults, so you can also just tell Claude to override them for a given project.

## Sharing

Send people the repo link. They can install any skill the same way as above.

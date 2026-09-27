# my-agent-skills

Reusable skills for Claude (the Claude app, Cowork and Claude Code). Each skill lives in its own folder under `skills/` with a `SKILL.md` inside, plus optional `references/` and `templates/` the skill points to. Install the whole folder, not just SKILL.md.

## Skills

| Skill | What it does |
| --- | --- |
| [loop-engineering](skills/loop-engineering/SKILL.md) | Plan-first, test-gated build loop for API-first apps: plan, mocks, OpenAPI design and test plans up front, then build each phase, gate it on tests and ship to beta before prod. Defaults to Cloudflare Workers and Pages, Clerk, portable Postgres (Neon or Supabase) and R2, and comes with lessons learned from production incidents. |

## Installing a skill

### Claude app or Cowork

1. Download this repo (green **Code** button, then **Download ZIP**) and unzip it.
2. Zip the single skill folder you want, for example `skills/loop-engineering`, so the zip contains `loop-engineering/SKILL.md`.
3. In Claude, open Settings, find the Skills section and upload that zip.

### Claude Code

Copy the skill folder into your personal skills directory:

```bash
git clone https://github.com/bilgrami/my-agent-skills.git
cp -r my-agent-skills/skills/loop-engineering ~/.claude/skills/
```

Or put it in a project's `.claude/skills/` folder to share it with everyone on that repo.

## Customizing

Skills are plain Markdown. Fork the repo or edit `SKILL.md` directly to swap in your own stack, models or rules. The loop-engineering stack rules are labelled as defaults, so you can also just tell Claude to override them for a given project.

## Sharing

Send people the repo link. They can install any skill the same way as above.

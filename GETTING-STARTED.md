# Getting started: point Claude at your project and bring it up to date

This guide is for someone new to Claude skills. By the end you will have Claude read your app, tell you in plain words what shape it is in, and then fix the problems one safe step at a time.

Two skills work together:

- **architecture-upgrade** looks at your project and writes you a report and a plan. It changes nothing until you say yes.
- **loop-engineering** is how the fixes get built: tests first, one phase at a time, tried on a test copy of your app (called "beta") before your real users ever see it.

You only ever talk to Claude. The skills tell Claude how to work.

## What you need

- The Claude desktop app (for Cowork) or Claude Code, on a plan that supports skills.
- Your project's code on your computer, ideally in a git repository.
- About 30 minutes for the first look, and time to read the report.

## Step 1: Install the two skills (5 minutes, once)

**In the Claude app or Cowork**

1. Open this repo on GitHub and go into the `dist/` folder.
2. Download `loop-engineering.zip` and `architecture-upgrade.zip` (open each file, then use the download button).
3. In Claude, open Settings, find **Skills**, and upload both zips. Do not unzip them.

**In Claude Code**

```bash
git clone https://github.com/bilgrami/my-agent-skills.git
cp -r my-agent-skills/skills/loop-engineering my-agent-skills/skills/architecture-upgrade ~/.claude/skills/
```

## Step 2: Point Claude at your project

- **Cowork:** start a new task and add your project's folder with the **Add folder** button (or let Claude ask for access when you name the folder).
- **Claude Code:** open a terminal in your project's folder and run `claude`.

## Step 3: Ask for the check-up (plan only)

Paste this, and swap in your folder name:

> Use the architecture-upgrade skill on my project in `<your folder>`. Plan mode only: read everything, change nothing. Write the architecture page, the gap report and the phased plan, show them to me, and ask me your questions.

Claude will read your code, settings, deploy scripts and tests. It does not deploy, run migrations, change settings or spend money on AI calls during this step.

## Step 4: Read what comes back

You get three documents:

1. **Architecture page.** Your app in plain language: what it is built with, how a typical request or job moves through it, and where it runs and how changes go live. Check this first. If it is wrong about your own app, tell Claude before going further.
2. **Gap report.** Each problem found, with:
   - a severity: **Critical** (you could lose or leak data or money, or one failure takes everything down), **High** (a likely outage or bad release with no safety net), **Medium** (slows you down or hides problems), **Low** (tidying);
   - the evidence (the exact file and line, so you can check it yourself);
   - why it matters, in one sentence;
   - which phase of the plan fixes it.

   It also lists **what is already good**, so the fixes do not break it.
3. **Phased plan.** The fixes in order, most important first, each small enough to ship on its own, with "done when" in plain words and the things only you can do (create an account, add a secret, approve a cost).

A typical first plan looks like this:

- Phase 1: a safe test copy (beta) with its own database, so changes are tried before they reach real users.
- Phase 2: backups that are actually tested by restoring them.
- Phase 3: move anything the browser does straight to the database behind your app's own server.
- Phase 4: tidy secrets and loose files.

## Step 5: Answer the questions and approve

Claude ends with a short list of questions only you can answer (which hosting plan you are on, what budget is fine, which user journeys matter most). Answer them in plain words. Then either:

- say **"approve the plan"**, or
- change it first: "do Phase 2 before Phase 1", "skip Phase 4 for now", "keep n8n, don't move anything out of it yet".

Nothing is built until you approve.

## Step 6: The upgrade (loop engineering)

For each phase, Claude:

1. writes the tests that prove the fix,
2. makes the change,
3. runs your project's own checks, and fixes anything that fails (it stops and tells you after three failed tries instead of going round in circles),
4. has a second, fresh reviewer check the work,
5. saves it with a clear note, and ships it to beta,
6. gives you a short list of **things to try**, like "open the dashboard on beta, add a lead, you should see it in the list within a few seconds".

Try those things. If something looks wrong, say so in your own words. When a phase is good, Claude moves to the next one.

**Claude always stops and asks before:** going live to real users, changing data that already exists, deleting anything, changing live automations, touching DNS or security settings, or anything that costs money. Those steps are yours.

## Picking up later

Claude keeps notes in your project under `agents/<date>-architecture-audit/` (the report, the plan and a progress log, newest first). In a new session, just say:

> Read the latest folder in agents/ and carry on with the plan.

## Tips

- **Start with plan mode on anything important.** Read the report before approving a single change.
- **You can stop any time.** Each phase leaves the app working.
- **Different stack? Fine.** The skill fixes things inside the tools you already use. Moving to other services is only ever offered as an optional last step.
- **Evidence beats opinion.** If a finding has no file or command behind it, ask Claude to show you or drop it.
- **Keep your secrets secret.** Claude never prints passwords or keys; if you are asked to paste one into the chat, put it in your `.env` file instead and tell Claude where it is.

## Words you will see

- **Beta:** a private copy of your app with its own database, where changes are tried first.
- **Prod / production / live:** the real app your users use.
- **Promote:** moving a change from beta to production, after it has run on beta for a while.
- **Migration:** a saved change to the database's structure, applied in order.
- **API-first:** the browser only talks to your app's server, never straight to the database.
- **RLS (row level security):** database rules that stop one user or business from seeing another's data.
- **CI:** automatic checks that run every time code is saved to GitHub.
- **Smoke test:** a quick automatic check that the live site loads and answers after a deploy.
- **Rollback:** putting the previous version back if something goes wrong.

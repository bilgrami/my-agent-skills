---
name: architecture-upgrade
description: Audit an existing app's architecture, write a plain-language architecture page and evidence-backed gap report, plan fixes in phases within its current stack, then fix them with a test-gated loop. Use when asked to review, audit, harden or fix an app's architecture.
---

# Architecture Upgrade

Takes an app that already exists, finds what will hurt it, and fixes it in safe phases without forcing a new stack. Companion to the **loop-engineering** skill: this skill decides *what* to fix; loop-engineering's build loop is *how* each phase gets built. If loop-engineering is installed, read its `references/lessons.md` and `templates/` too. If it is not, the essentials are repeated here.

## Ground rules

- **Read only until the plan is approved.** Discovery and audit change nothing: no deploys, no migrations, no config edits, no workflow edits, no paid calls.
- **Fix within the current stack.** If the app is Next.js in Docker with Supabase and n8n, the fixes use Next.js, Docker, Supabase and n8n. A move to another platform is offered only as an optional last phase.
- **Evidence or it is not a finding.** Every finding cites a file and line, a config value or a command's output. "Probably" goes under open questions, not findings.
- **Check the live system, not just the repo,** for anything that depends on out-of-band state (env vars, secrets present, applied migrations, deployed version, n8n workflows actually active). Read-only.
- **Plain language** in everything the owner reads. No em dashes.
- **Never print secrets.** Note that a secret exists and where, never its value.

## Step 1: Discover (read only)

Build a picture of the app from the code and config:

- Package manifests, framework and runtime versions, Dockerfile and compose files, reverse proxy config (Traefik, nginx), CI workflows, hosting config.
- Database: migrations folder, RLS policies, SQL functions, how migrations are applied, generated types.
- Auth: provider, how users map to accounts or organizations.
- Every place the browser talks to a backend: API routes, server actions, direct database or storage clients in client code.
- Automation: exported n8n (or similar) workflows, their triggers, and what they call.
- Outside services: messaging, voice, AI, email, calendar, billing, error tracking, backups. Where their webhooks land.
- Tests: what exists, how many, what they run against.

Write `docs/architecture.md` from `templates/architecture.md`: what it is built with, how the main user journey flows step by step, where it runs and how changes go live. Say it was checked against the code and when.

## Step 2: Audit

Go through `references/audit-checklist.md` area by area. For each check record: pass, finding, or not applicable (with the reason). For each finding: severity, evidence, why it matters in one plain sentence, and the playbook that fixes it.

**Severity:**

- **Critical:** data loss, data exposure across users or tenants, money lost or unbilled, or a single failure takes everything down with no tested way back.
- **High:** a likely outage or bad release with no safety net (for example no beta, core logic untested).
- **Medium:** slows every change or hides problems (missing guards, drift, weak observability).
- **Low:** hygiene.

**Default priority order** (the owner can reorder):

1. **Beta before prod.** Changes reach production without passing through a separate environment with its own database.
2. **API-first.** The browser talks to the database or storage directly, or business rules live in client code.
3. **Core logic out of the workflow tool.** Business rules, mid-conversation tools or money-affecting decisions live in n8n (or similar) where tests cannot see them.
4. **Single-server risk.** One box runs everything with no monitoring, rebuild runbook, off-box files or tested restore.
5. Everything else, by severity.

Write the gap report from `templates/gap-report.md` into `agents/<yyyy-mm-dd>-architecture-audit/gap-report.md`.

## Step 3: Plan

Turn findings into phases, most important first. Each phase:

- fixes one theme, is shippable on its own, and leaves the app working,
- names its playbook from `references/fix-playbooks.md`,
- has a Definition of Done in plain words and the tests that prove it,
- lists the owner actions it needs (new accounts or projects, DNS, secrets, paid plans).

Quick, safe wins (pre-commit secret scan, docs, missing tests) can ride along with Phase 1. Anything touching data, deploys, DNS, n8n in production or money is its own step with a rollback.

Then:

- Self-critique the plan, and have a fresh reviewer agent critique it again. Fix the gaps.
- Ask the owner your clarifying questions (AskUserQuestion when available), one short round.
- Save `plan.md` beside the gap report and **wait for explicit approval.**

## Step 4: Fix, phase by phase

Use loop-engineering's build loop if installed. Otherwise, per phase:

1. Write the tests that prove the fix first; confirm they fail (or that the risk is demonstrable).
2. Implement following the playbook.
3. Run the repo's own checks (types, lint, tests, build). Max 3 attempts per failure, then stop and report.
4. Never weaken, skip or delete a test to pass.
5. A fresh reviewer agent checks the diff against the plan and Definition of Done.
6. Commit with explicit paths only (never `git add -A`). Update `progress.md`, newest entry first.
7. Ship to beta once beta exists (before that, follow the app's current deploy path and say so). Verify the effect live.
8. Give the owner a plain-language list of what to try and what they should see.

**Stop and ask before:** production deploys or promotes, schema changes to existing data, anything destructive, changing or disabling live n8n workflows, DNS or proxy changes, new paid services, rerunning paid jobs.

## Done means

Every approved phase is live on beta (and promoted where the owner approved), the architecture page is current, the gap report marks each finding fixed, deferred or accepted, and `progress.md` says what is left.

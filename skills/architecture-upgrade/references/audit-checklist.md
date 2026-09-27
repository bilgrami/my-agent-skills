# Audit checklist

Work through each area. For every check, record pass, finding (with evidence) or not applicable (with the reason). The "how to check" lines are starting points; adapt the commands to the repo. Everything here is read only.

## 1. Shipping and environments

- **Is there a beta (or staging) environment separate from prod?** Own URL, own deploy, and above all its own database. How to check: CI workflow triggers and targets, compose files, env files per environment, database project refs or connection strings named per environment.
- **What reaches prod, and how?** Does a merge to main deploy straight to prod? Is there a promote step, a soak, a smoke test after deploy?
- **How are migrations applied, and to which database?** Same step as the deploy, before it, by hand? Are they replay-safe (`IF NOT EXISTS`, `ON CONFLICT DO NOTHING`, `CREATE OR REPLACE`)? Any duplicate version prefixes (`ls <migrations> | sed -E 's/_.*//' | sort | uniq -d`)?
- **Rollback:** can the previous version be redeployed in minutes? Are schema changes additive so rolling code back is safe?
- **Version visible?** Can a person tell which build is live?
- **Does CI run on the branch you actually ship from?** If deploys go from a `beta` or `staging` branch, CI must trigger on pushes to it, and promote should require a green run for that exact commit.
- **Is the CI config itself valid?** Duplicate job names, jobs that never run, steps marked report-only. Check the Actions history, not just the file.
- **Uncommitted or stranded work:** modified files on a deploying branch, migrations or code parked in staging folders outside the normal paths, tracked tarballs or bundles, locked worktrees from old sessions.
- **What shares production?** List every piece beta or staging shares with prod (database, workers, functions, queues, keys). A beta that shares the database cannot test migrations.
- **Scheduled-job and platform limits:** cron schedules per account, queue and worker limits, so new environments do not silently lose their jobs.

## 2. API-first

- **Does the browser talk to the database or storage directly?** How to check (Supabase + Next.js): search client code for `createClient`, `createBrowserClient`, `supabase.from(`, `supabase.rpc(`, `supabase.storage` in files marked `"use client"` or under components and hooks; env vars prefixed `NEXT_PUBLIC_SUPABASE`. Count occurrences and list files.
- **Is any privileged key exposed?** A service role key in any `NEXT_PUBLIC_` variable, client bundle or repo file is Critical.
- **Where do business rules live?** Server (API routes, server actions, SQL functions) or client components? Rules in the client are bypassable.
- **Is there a contract?** OpenAPI or typed route definitions, stable error codes, validation on input (zod or similar)?
- **Do other clients (n8n, voice agents, partners) use the same API**, or do they reach the database with their own credentials?

## 3. Database and migrations

- **RLS on every table with user or tenant data?** List tables without RLS enabled.
- **Write policies have explicit `WITH CHECK`?** `FOR ALL USING (...)` without `WITH CHECK` lets a user insert anything they could read.
- **Tenant isolation:** every tenant table has a non-null tenant id, indexed, and policies compare it to the caller's claim. Is there a test that proves one tenant cannot read another's rows?
- **SECURITY DEFINER functions** that write sensitive tables: do they check the caller?
- **Generated types fresh?** Compare against `information_schema` for tables migrations touch.
- **Loose SQL files** outside the migrations folder that look like they were run against prod.
- **Slow reads:** views or RPCs the app calls that are near the statement timeout.

## 4. Automation (n8n or similar)

- **Inventory every workflow:** trigger (webhook, schedule, app event), what it reads, what it writes, what it decides. Are they exported into the repo, and does the export match what is active?
- **Where is the logic?** Flag any workflow that decides something the business depends on: scoring, eligibility, pricing, who to chase and when, anything a live conversation waits on (mid-call tools). These belong in tested API operations.
- **How does n8n reach data?** Database credentials in n8n are a finding; it should call the API with a scoped token.
- **Webhook security:** are inbound webhooks (to n8n and to the app) signature-checked? Are calls from n8n to the app signed and idempotent?
- **Failure handling:** error workflow per workflow, retries with backoff, safe to rerun, alerts reach a person.
- **Environments:** does beta have its own workflows and credentials, or would testing a workflow touch real customers?
- **Personal data** in execution logs: retention period.
- **Hosting:** is the n8n editor protected (SSO or access proxy), and is only the webhook path public?

## 5. Hosting and resilience

- **Single points of failure:** one server running app, proxy and maybe more? What happens if it dies at 2am?
- **Monitoring:** uptime checks from outside, alerts to a phone, a health endpoint that checks the database.
- **Rebuild:** is there a written, tested way to rebuild the server from nothing (provisioning, secrets, compose up, DNS)? How long would it take?
- **State on the box:** uploaded files, recordings, logs, anything not in the database or object storage. It should all be off the box.
- **Backups:** what, how often, where (a different provider from the host), encrypted, and when was a restore last tested into a scratch database with row counts checked?
- **Proxy and TLS:** certificate renewal automatic, rate limits and basic protection on, admin panels not public.
- **Resource limits:** container memory limits, disk space alerts, log rotation.

## 6. Security and personal data

- Secret scanning in pre-commit and CI; any secrets in git history.
- Secrets in env or a secret store, never in code or client bundles, and never in files named like templates (`*.example`) that get copied and shared.
- Old database dumps or exports lying on laptops or in the repo folder: they are personal data outside any access control.
- Webhooks from every provider (payments, telephony, voice, auth) verified by signature.
- Payments: credits or plans granted only after the provider's webhook, never from the client.
- Error tracking scrubs personal data.
- Recordings, transcripts and documents: who can access, how long kept.
- Admin screens: role-checked on the server, not just hidden in the UI.

## 7. Tests and checks

- What runs on every change: types, lint, unit, e2e, database tests against a real Postgres.
- Is the typecheck real? (A solution-style `tsconfig.json` with `"files": []` makes a bare `tsc --noEmit` check nothing.)
- Do tests cover the core journey end to end, including webhooks (replayed fixtures)?
- Post-deploy smoke tests against the live site.
- Any skipped, flaky or import-broken test files.

## 8. AI and voice agents (if present)

- Agent tools: are they API operations with a scoped token, or workflow calls, or direct database access?
- Post-call or post-run webhooks: verified, stored idempotently by id, processed in a job.
- Prompts and agent configs versioned in the repo and pushed per environment?
- Knowledge search: vectors stored with the tenant id and filtered by tenant before similarity?
- Usage and cost recorded per call and per tenant.
- Model token budgets allow for thinking plus answer; empty answers are errors, not blanks.

## 9. Observability

- Errors from web, API, jobs and n8n land in one place with the release version.
- Background jobs: can a person see what is queued, running, failed, and why?
- Logs carry a request id across app, n8n and outside services.

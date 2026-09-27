---
name: loop-engineering
description: Plan-first, test-gated build loop for API-first apps on Cloudflare, Clerk and portable Postgres (Neon, Supabase), with R2 files, Redis caching and staged beta-to-prod shipping. Use when starting a new feature, app or phase of work.
---

# Loop Engineering

A plan-first, test-gated build loop. Nothing gets built until the plan is approved. Each phase is implemented, tested, reviewed and shipped to beta before the next one starts. The rules here come from real incidents on production apps; the stories behind them are in `references/lessons.md`. For an app that already exists, start with the companion **architecture-upgrade** skill, which audits it and plans the fixes, then uses this loop to build them.

## Model roles

The model reviewing code is never the one that wrote it.

- Planner and reviewer: Opus 5.5, high effort for Phase 0 and plan critique, medium for in-loop reviews.
- Builder: Fable 5.1 (swap roles if the other model does better on this codebase).
- Reviews run in a separate agent with fresh context, never as self-review in the builder's context.

## Stack (defaults; the user can override per project)

- **Web:** React + Vite + TypeScript on Cloudflare Pages.
- **API:** a Cloudflare Worker (Hono) at `api.<domain>`, versioned under `/v1`. A second Worker for cron and queues if needed.
- **Database:** plain, portable Postgres. Neon (free tier) for dev, beta and demo; Neon or Supabase for prod. The Worker reaches it through Hyperdrive. Business rules live in named SQL functions and row level security, so the same migrations run on any Postgres host.
- **Cache, search and fast counters:** Cloudflare's own primitives first (rate limiting binding, KV, Queues, Durable Objects). Add Redis over HTTP (for example Upstash) only when you need its data structures or RediSearch. Redis is always a derived copy of Postgres, reached through one gateway module, never the source of truth.
- **Files:** Cloudflare R2, one bucket per environment, served only through the API with short-lived signed links.
- **Auth:** Clerk with custom branding and a custom domain. The Worker verifies the Clerk JWT; the database trusts only tokens the API signs.
- **Admin sites:** behind Cloudflare Access (free Zero Trust), with Clerk as the identity provider.
- **MCP server:** just another API client. It calls API operations in process and never imports the database layer.
- **Billing:** Stripe. Webhooks verified by signature; money and credits granted only by the server after the provider's proof.
- **Errors:** Sentry on web, API and jobs, with personal data scrubbed before it leaves.
- **Backups:** a nightly database dump to R2 (a different provider from the database host), with a restore that has actually been tested.
- **Automation:** n8n for integration glue (lead intake, reminders, syncing with outside tools), one instance per environment on its own subdomain. It is another API client: it calls the API with a scoped service token and never touches the database. Business rules stay in the API and database, not in workflows. Workflows are exported into the repo. Details in `references/stack-setup.md`.
- **Other outside services** (AI, voice, messaging, calendars) are called from the API or jobs Worker, never the browser; their prompts and configs live in the repo.
- **Multi-tenant apps:** each customer business is a Clerk Organization and a tenant id on every row; RLS keys on it, and a test proves one tenant cannot read another's data.
- **AI and voice agents:** the agent's tools are API operations with a scoped token, post-call or post-run webhooks are verified and idempotent, prompts live in the repo, and embeddings live in Postgres (pgvector) per tenant. See `references/stack-setup.md`.
- **Environments:** dev (local), beta, demo, prod, listed in one `deploy/environments.toml`. Each has its own Worker, database, bucket, secrets and Clerk instance. Demo runs on seeded, resettable fake data.

Setup details: `references/stack-setup.md`. Shipping flow: `references/shipping.md`.

## API first, enforced from day one

Retrofitting API-first later is brutal (one app still had over a thousand direct database calls to unwind a year in). So the guard rails are part of the first phase, not a cleanup:

- The web app has no database client. A lint rule refuses the import and a CI script holds the count of direct calls at zero.
- The CSP names no database or storage host.
- Every operation in the OpenAPI spec has a handler; a coverage test fails if one is missing.
- Rows are mapped to responses in one module and failures to stable error codes in one module. A handler that returns a raw row is a bug.
- There are no private endpoints for your own screens. If a screen needs it, the API offers it to every client with that role.

The order of work for any feature: **contract** (OpenAPI, additive changes only, a changelog line) → **database** (migration, SQL functions, RLS, SQL tests) → **gateway** (handler and tests) → **generate** (types, client, docs; commit what changes) → **screen** (typed client only) → **deploy the API before the web app that needs it**.

## Phase 0: Plan (no code until the user approves)

For every new feature, produce:

1. Feature breakdown: features, then phases. Each phase is shippable and testable on its own, with a written Definition of Done.
2. Mocks: UI mockups for each screen, plus MSW API mocks so frontend work can start before the API exists.
3. API design as OpenAPI: resources, endpoints, schemas, error codes, auth rules, pagination, limits.
4. API docs generated from the spec.
5. Data model and migrations, each replay-safe, with a rollback and a closing verification query. Any Redis keys or indexes, and how they are rebuilt from Postgres.
6. Unit test plan and e2e test plan, mapped to each phase's Definition of Done.
7. Risks, open questions, and the owner actions the plan will need (accounts, tokens, DNS).
8. A plain-language **Stack and architecture** page (`docs/architecture.md`, from `templates/architecture.md`): what it is built with, how the main user journey flows through it step by step, and where it runs and how changes go live. Checked against the code, not written from memory, and updated whenever a service is added or removed.

Then:

- **Check the live system, not just the repo.** If the plan depends on data, a secret, a flag or a deployed version, confirm it with a query or a request. Repo reading generates hypotheses; the live system settles them.
- Self-critique the plan: edge cases, auth gaps, error and empty states, environment differences, anything untestable. Fix the gaps.
- A separate reviewer agent critiques it again with fresh context. Fix what it finds.
- Ask the user clarifying questions (AskUserQuestion when available).
- Wait for explicit approval.

If the feature has a design, build only once the design is approved; changing the design resets approval.

Save the approved plan to `agents/<yyyy-mm-dd>-<task>/plan.md` using `templates/plan.md`.

## Build loop (per phase)

1. Write the phase's unit and e2e tests first, from the plan. Confirm they fail.
2. Implement the phase in the contract-first order above.
3. A pre-commit hook runs a secret scan, lint, types and an unused-code check (for example knip) on staged files. Then run gates with **the repo's own scripts** (`npm run verify` or equivalent), never a hand-typed substitute. Order: typecheck, lint, guard scripts, unit, SQL tests, build, e2e (Playwright with Clerk testing tokens).
4. If anything fails: find the root cause, fix, rerun. Max 3 attempts per failure, then stop and report what was tried.
5. Never skip, weaken or delete a test to make it pass. If a test looks wrong, stop and explain why. Before overriding any check, read its code; the fix is usually on your side.
6. A reviewer agent checks the diff against the plan and the Definition of Done. Fix gaps, rerun gates.
7. Bump the app version (at least a minor) and add a changelog line for any change users can see; update the matching help page in the same batch. Update `progress.md` (newest entry first) and commit with explicit file paths. Never `git add -A` or other blanket staging.
8. Ship to beta (`references/shipping.md`): migrate, deploy API then web, smoke test. **Verify the effect** with a query or request; a clean exit code is a claim, not proof.
9. Give the user a plain-language list of what to try on beta and what they should see. No jargon, no test names.
10. Next phase.

`progress.md` is the resume point. At the start of any session, read the newest `agents/` folder first.

## Hard rules (each one cost an incident; see references/lessons.md)

- **Migrations:** replay-safe (`ON CONFLICT DO NOTHING`, `NOT EXISTS` guards, `CREATE OR REPLACE`). Pick the version number at commit time and recheck at push time. Unique version per file. Build test fixtures from the real `CREATE TABLE`, never from a spec's prose. Every write policy has an explicit `WITH CHECK`. For anything a migration writes, `information_schema` beats generated types.
- **"Fixed" means deployed.** Every fix names which side of the deploy boundary it is on.
- **A gate is real only if you have seen it fail.** Break it on purpose once. A test file that cannot import is a failure, not a pass.
- **Redis:** one gateway module holds the credentials and every command goes through it. No raw TCP clients from Workers or serverless functions; no connection cached per isolate. A new RediSearch field needs `FT.ALTER` plus a full rehydrate. Escape dashes in TAG values. A mock or fallback client must be loud, never the silent default in a deployed environment.
- **Data repairs** are reviewable: a read-only script writes the fix as SQL plus a CSV of what it decided and what it could not, with an undo script, applied in one transaction. Never hand-edit production rows.
- **Never state a number the data does not hold** in generated text or reports. Leave a marked gap for a person.
- **Contracts between producer and consumer:** before writing code that produces a URL parameter, event or payload, open the code that consumes it. One shared constant or builder, never two hand-typed copies.
- **Background jobs:** healthy means produced output, not exit 0. Partial success is failure. Jobs are idempotent and sized to fit the time limit. A failed predecessor blocks its dependents. System work is never billed to a user.
- **Paid model calls** run only through the queue, never from a shell. Budget max tokens for thinking plus answer; an empty answer throws and the raw attempt is logged.
- **Fail closed, loudly, and only as wide as needed.** A swallowed error in a security path is an outage nobody can see.
- **UX:** a disabled control says why. Show the server's reason, not a generic error. A screen that queues work shows that work's progress. Never gate a capability on something the user can do without; skip the dependency and say so.
- **Removing a surface:** list everything that only lives there and rehome it first.
- **Secrets:** never printed, never in `VITE_` variables or the repo. Read `.env` only inside scripts.
- **Repo hygiene:** scratch scripts, one-off SQL and temp files go in a git-ignored `scratch/` folder, never the repo root. Anything that changes a database is a migration or an audited repair script, never a loose `.sql` file.
- **Public assets use invented data.** Anything in `public/` is one URL from anyone, so screenshots and help images never show real names or amounts.

## Stop and ask the user before

- Any change to the approved plan or API contract
- Schema migrations that touch existing data
- Anything destructive (drops, deletes, force pushes, bucket or database deletes)
- Promoting to demo or prod
- Rerunning a failed paid job (it spends money)
- Adding a dependency, third-party service or paid plan
- Any action that needs an account, card, password or security setting (those are owner actions)

## Done means

All phases green on beta, docs match the code, `progress.md` is current, and a short report covers what shipped, what deviated from the plan, what is waiting on the owner, and what to try.

## Style

No em dashes in any output. Plans, progress notes and reports in plain prose where it reads better than a checklist.

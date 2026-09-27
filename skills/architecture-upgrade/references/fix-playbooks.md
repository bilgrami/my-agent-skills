# Fix playbooks

Step-by-step recipes for the common fixes, written for an app on Next.js, Supabase, Docker and n8n. Adapt names to the repo. Each playbook ends with how to prove it worked. Items marked **owner** need the owner (accounts, DNS, secrets, money).

## P1. Beta before prod

Goal: every change runs on a beta environment with its own database before it can reach prod.

1. **owner:** create a second Supabase project for beta (same region as prod), and a beta subdomain (`beta.example.com`) pointing at the server.
2. Migrations: make every file replay-safe, then apply the full migrations folder to the beta project. Compare schemas (a fingerprint query over tables, columns, policies, functions, triggers, indexes) until beta and prod match.
3. Seed beta with invented data (a seed script, never a copy of prod customers). If tenants exist, seed two so isolation tests have something to prove.
4. Outside services per environment: separate Clerk instance or at least separate keys, test-mode Stripe, sandbox or test numbers for telephony, a separate voice agent config, separate n8n credentials (see P3). Nothing on beta can message a real customer.
5. Docker: a `beta` service (or compose project) with its own env file, behind Traefik on the beta host. Memory limits on both.
6. CI: merge to main deploys to **beta** (build image, apply migrations to beta, restart, smoke test). Prod deploys only from a manual promote job that takes the exact image beta ran.
7. Promote job gates: beta smoke test green, beta running the commit for a soak period (24 hours by default, emergency override is an owner decision), migrations rehearsed against prod inside a transaction and rolled back, then apply for real, deploy, smoke test prod.
8. Show the version in the footer and a `/health` endpoint that reports version and checks the database.

Prove it: a harmless change lands on beta only; the promote job moves exactly that image to prod; prod's health endpoint shows the new version.

## P2. API-first (Next.js + Supabase)

Goal: the browser never talks to the database or storage; every read and write goes through the app's server.

1. Inventory: list every client-side Supabase call (file, table or RPC, read or write). This is the migration backlog; record the count.
2. Add a guard first so the count cannot grow: an ESLint rule (`no-restricted-imports`) banning `@supabase/*` in client code, and a CI script that counts client calls and fails above the recorded number. Lower the number as you go (a ratchet).
3. For each call, add a server endpoint (route handler under `app/api/v1/...` or a server action), validated with zod, that runs as the signed-in user (pass the user's token so RLS still applies) or calls a named SQL function. Stable error codes, one mapping module for rows to responses.
4. Replace the client call with a typed fetch to the endpoint. Keep RLS on; it is the second wall.
5. Storage: uploads and downloads go through short-lived signed URLs issued by the server for exactly one path and content type.
6. When the count reaches zero: remove the public Supabase env vars from the client, and tighten the CSP so it names no database or storage host.
7. Make other clients (n8n, voice agents) use the same endpoints with scoped service tokens instead of database credentials.

Prove it: the guard count is zero in CI, the client bundle contains no Supabase URL or key, and the app works end to end on beta.

## P3. Core logic out of n8n

Goal: rules the business depends on live in tested API operations; n8n keeps orchestration and glue.

1. Classify each workflow from the audit inventory: **glue** (move data, send a message, sync a calendar) stays; **logic** (scoring, eligibility, who to chase and when, anything a live call waits on) moves.
2. For each logic piece: write tests from the workflow's current behaviour first (fixture inputs and expected outputs, including edge cases), then implement it as an API operation. For mid-call tools, keep response time low and return a clear error the agent can speak.
3. Point the caller at the new operation (the voice agent's tool definition, or the n8n HTTP node), with a scoped token and a signature header. Run old and new side by side on beta and compare results before switching.
4. n8n hygiene for what stays: one instance or separate credentials per environment, editor behind SSO or an access proxy, inbound webhooks signature-checked in the first node, calls to the API signed with an idempotency key, an error workflow on each that alerts a person, retries with backoff, execution data pruned after a short period.
5. Workflows as code: export to `n8n/workflows/*.json` after every change, commit, import to prod by script as part of the promote. No hand edits in prod. Credentials are named the same in each environment and never exported.
6. Paid steps (model calls, SMS, voice) run through the API or a job so cost is recorded per tenant.

Prove it: the moved logic has passing tests, beta runs on the new operations, and the n8n workflows that remain contain no business decisions.

## P4. Single-server risk

Goal: if the server dies, you know within minutes and can be back within a known time, with no data lost.

1. Monitoring: an outside uptime check on `/health` (which checks the database) for prod and beta, alerting a phone. Disk, memory and certificate expiry alerts.
2. State off the box: uploaded files, recordings and documents move to object storage (Cloudflare R2 or similar). Logs ship off the box or rotate.
3. Backups: nightly database dump to a different provider, encrypted, with lifecycle rules. A scheduled restore into a scratch database that checks row counts for key tables, reported somewhere a person sees.
4. Rebuild runbook, tested: provision a fresh server, install Docker, pull images, restore env from the secret store, compose up, switch DNS. Time it on a throwaway server and write the time down.
5. Infrastructure as code where cheap: compose files, Traefik config and provisioning script in the repo.
6. Decide, with the owner, whether a warm standby (a second small server kept up to date, DNS switch on failure) is worth the cost given the rebuild time. Record the decision.

Prove it: a restore drill passes, the rebuild was timed, and a simulated outage (stop the container on beta) triggers an alert.

## P4b. Workers on Fly.io

Goal: long-running workers are right-sized, observable, per-environment and deployed from what is committed.

1. Inventory each Fly app: role, config file, machine size, schedule, secrets it needs (names only), and which database it points at.
2. Split beta from production: beta apps with their own names, secrets and database; beta workers capped on paid calls.
3. Right-size from measurement: run a representative job, record peak memory, set size with headroom. Log exit signals.
4. Add a heartbeat and a stale-heartbeat alert; alert on queue depth and dead-lettered jobs.
5. Deploys from CI or a script that refuses a dirty tree; scheduled bundles rebuilt and committed with their source.
6. **owner:** run `fly deploy` and `fly secrets set` from the printed commands.

Prove it: a forced OOM on beta is logged with its signal and alerts; the stale-heartbeat alert fires when a beta worker is stopped; `fly releases` matches the deployed commit.

## P5. Quick safe wins (can ride with Phase 1)

- Pre-commit: secret scan (for example gitleaks), lint, types, unused-code check (for example knip) on staged files.
- A real typecheck script that actually checks the app's tsconfig.
- `docs/architecture.md` from the template, kept current.
- A `agents/` folder convention for plans and progress.
- Replay-safe migrations and a duplicate-prefix check in CI.
- Webhook signature checks where missing.
- Sentry scrubbing personal data, release tagged with the app version.

## P6. Optional later: move toward the loop-engineering defaults

Only if the owner wants it, after P1 to P4. Typical order: files to R2 (already done in P4), beta database to Neon, API routes to a Cloudflare Worker with Hyperdrive, static site to Pages, then prod. Each step keeps the app working and ships through beta.

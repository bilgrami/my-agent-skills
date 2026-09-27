# Stack setup

How the default stack fits together. Free tiers and limits change, so check each provider's current pricing page before promising the user anything is free.

## Environments

One file lists every environment; scripts read it, nothing hardcodes addresses.

```toml
# deploy/environments.toml
[beta]
enabled = true
branch = "beta"
web = "https://beta.example.com"
api = "https://api-beta.example.com"
database = "neon"
database_url = "NEON_BETA_OWNER_URL"   # name of the .env entry, never the value

[demo]
enabled = true
branch = "beta"
web = "https://demo.example.com"
api = "https://api-demo.example.com"
database = "neon"
database_url = "NEON_DEMO_OWNER_URL"
seed = true                              # reseeded fake data, never real users

[prod]
enabled = true
branch = "main"                          # only a promote moves it
web = "https://example.com"
api = "https://api.example.com"
database = "neon"                        # or "supabase"
soak_hours = 24
```

Each environment gets its own Pages project, API Worker, database, R2 bucket, secrets and Clerk instance. Nothing is shared except code.

## Database: portable Postgres

- Write plain Postgres: tables, named SQL functions for every write, row level security for every read. Avoid host-specific features in business logic, so the same migrations run on Neon, Supabase or a local Postgres in CI.
- A bootstrap SQL file creates what a managed host would otherwise provide (roles such as `anon`, `authenticated`, `service_role`, the helper that reads the caller from `request.jwt.claims`, and a migrations history table).
- The API connects with its own login role that can do nothing by itself except become one of those roles for the length of a transaction. Each request runs as one short transaction that sets the role and claims first, so RLS decides everything.
- **Neon:** one project per environment (free tier covers dev, beta and demo well). Owner connection string for migrations, a separate API connection string for the Worker. Pick a region near your users and prod.
- **Hyperdrive:** the Worker reaches Postgres through a Hyperdrive config per environment (caching off unless you have measured a reason). Test it with a deep health check: `/health?deep=1` signs a token and runs a query.
- **CI:** run the SQL test suites and API tests against a real Postgres of the same major version on every push.
- **Parity:** a fingerprint query (tables, columns, functions, policies, triggers, indexes, constraints, grants, enums) lets you prove two environments have identical schemas. Keep an ignore list for objects a host template created that are not yours.

## Cache, search and counters: Cloudflare first, Redis when it earns its place

Start with what the platform gives you, per environment:

- **Rate limiting:** the Workers rate limiting binding (`type = "ratelimit"` in wrangler), one per class of endpoint.
- **KV:** config, feature flags and read-heavy caches that can be a few seconds stale.
- **Queues:** background jobs and retries, consumed by the jobs Worker.
- **Durable Objects:** anything that needs a single strongly consistent counter, lock or room.

Add Redis when you need sorted sets, streams, shared caches across services, or RediSearch. Rules:

- **Postgres is the truth; Redis is a derived copy.** A hydration job rebuilds it from Postgres (incremental on a schedule, `--full` on demand) and has a `--verify` mode that compares counts. Losing Redis must cost speed, not data.
- **Reach it over HTTP from Workers** (for example Upstash's REST API). Workers and most serverless platforms cannot hold a raw Redis TCP connection reliably, and some managed Redis hosts are not even resolvable from where your code runs.
- **One gateway module** owns the credentials and every command: the API, jobs and scripts all go through it. Debug scripts reuse it too, never `new Redis({host, port})`.
- **No per-isolate cached connections** if you do use TCP somewhere: warm isolates each hold one and exhaust the provider's max clients. Open per request or use HTTP.
- **Batch bulk work.** Every call is an HTTP hop, so hydration pipelines commands.
- **Key names** carry environment and version (`beta:v2:book:<id>`) so a schema change is a new prefix, not a flush.
- **RediSearch:** `FT.CREATE` is a no-op on an existing index, so a new field needs `FT.ALTER ... SCHEMA ADD` and a full rehydrate. UUIDs in TAG filters need their dashes escaped (`@ids:{a\-b\-c}`) or the query silently matches nothing. Put escaping in one shared helper.
- **A mock client must announce itself.** If dev falls back to an in-memory mock, it logs loudly and refuses to run in beta or prod, and docs never quote performance numbers the live system has not measured.

## Files: R2 through the API

- One R2 bucket per environment. The browser never gets a storage URL or key.
- The API hands out signed tickets: `/v1/files/<signed ticket>`, short-lived (minutes), bound to bucket, path, direction, content type and size limit. Tamper with any field and the API returns 404. The Worker streams bytes to and from R2 via a binding.
- Public assets (logos) can live under a public path the API serves without a ticket.
- Make the store a setting (`FILE_STORE=r2` with a binding) so you can migrate from another store without touching screens.

## Hosting

- Web on Cloudflare Pages, API and jobs on Workers. R2 stores files; it does not host sites.
- `public/_headers` sets a CSP that names your API and Clerk, and no database or storage host.
- Custom domains on Workers get certificates automatically, including nested subdomains, without a paid add-on.

## Auth: Clerk

- Custom branding and a custom domain (`accounts.example.com`). Separate Clerk instances for dev and prod.
- The Worker verifies the Clerk session JWT on every request, then signs its own short-lived token for the database. The database trusts only the API's signing keys.
- Sync users with Clerk webhooks and verify the signature.
- E2E tests sign in with Clerk testing tokens, never a real password.

## Admin sites: Cloudflare Access

- Put admin sites (`admin.example.com`) behind Cloudflare Access on the free Zero Trust plan, with Clerk as an OIDC identity provider and a group of staff emails.
- The admin edge Worker forwards `/api/*` to the API over a service binding, carrying the Access token.
- The API checks the Access token (team keys, issuer, expiry, audience, email matches the Clerk user) for staff operations. Roll out as off, then report (log only), then enforce.
- Switching on Zero Trust and creating OAuth apps are owner actions (a card may be needed even on the free plan).

## MCP server

- Expose the product to assistants as an MCP server at the API (for example `/mcp`), using OAuth or the same Clerk session.
- Tools map to public API operations and call them in process through the same dispatcher the HTTP routes use. The MCP module must not import the database layer; a test enforces it.
- Anything the MCP server needs that the API lacks is added to the API first, for every client.

## Guard scripts worth having from day one

- API-first check: no database client import in the web app (lint rule plus a script that fails on any count above zero).
- Coverage: every OpenAPI operation has a handler.
- Generated files are fresh: regenerate in CI and fail on a diff.
- Error codes: every code the API returns is documented in the contract.
- FK embeds: every embed in a query has a matching foreign key in the migrations.
- Duplicate migration versions: none, and no version prefix that is the start of another.
- No secrets in `VITE_` variables.

## Billing, errors, backups and outside services

- **Stripe:** checkout and portal from the API; webhooks verified by signature and processed idempotently (store the event id). Credits, plans and balances change only in the webhook path, never from the client.
- **Sentry:** one project per app, environment tagged, release set to the app version. Scrub personal data (emails, phone numbers, message bodies) in `beforeSend` and turn off default PII.
- **Backups:** a scheduled job dumps each prod database nightly to an R2 bucket with lifecycle rules, on a different provider from the database. Restore into a scratch database on a schedule and check row counts; an untested backup is a hope.
- **Workflow and AI services** (n8n, voice agents, messaging, model providers): called from the API or jobs Worker, never from the browser. Export workflows, prompts and agent configs into the repo; record each paid call's usage and cost.

## n8n (automation)

Use n8n for glue between systems: intake from forms and outside tools, reminders and follow-ups, syncing with calendars or CRMs, fan-out to email and messaging. Keep core business rules out of it; a rule that lives only in a workflow is invisible to tests, the API and every other client.

- **Hosting:** n8n Cloud or self-hosted on its own small server or container (it is a long-running Node service, so not on Workers). One instance per environment (`n8n-beta.example.com`, `n8n.example.com`), or at minimum separate credentials and workflows per environment. Put the editor behind Cloudflare Access; expose only webhook paths publicly.
- **n8n is an API client.** It calls your API with a service token scoped to the operations it needs, per environment. No database credentials in n8n, ever. Anything a workflow needs that the API lacks is added to the API first.
- **Inbound webhooks:** when n8n calls your API, sign the request (HMAC header with a shared secret) and include an idempotency key; the API rejects unsigned calls and ignores repeats. When outside services call n8n webhooks, verify their signatures in the first node.
- **Workflows are code.** Export them into the repo (`n8n/workflows/*.json`, via the n8n CLI `export:workflow` or the API) after every change and commit with explicit paths. Credentials are never in the export; they live in n8n's credential store and are named the same in every environment so an import works unchanged.
- **Promote like code:** build and try a workflow on beta, export, commit, import to prod. Do not hand-edit prod workflows.
- **Errors:** every workflow has an error workflow that reports to Sentry (or the API's error endpoint) with the execution id, never with personal data. Set retries with backoff on HTTP nodes, and make the steps safe to rerun.
- **Paid steps** (model calls, SMS, voice) go through the API or jobs Worker so usage and cost are recorded in one place, not inside n8n nodes.
- **Keep execution data short-lived** (prune after days, not months) since it holds payloads that may include personal data.
- **Test:** each workflow has a fixture payload and an expected API call or row; e2e tests on beta trigger the webhook and check the effect through the API.

## Multi-tenant (one app, many customer businesses)

- Each business is a Clerk Organization; the API reads the active org from the session and passes it to the database as a claim.
- Every tenant table has `tenant_id NOT NULL`, indexed, and RLS policies that compare it to the claim. Named functions check it too.
- Per-tenant settings (phone numbers, mailboxes, prompts, knowledge) live in tenant-scoped tables, never in env vars.
- A test signs in as two tenants and proves neither can read, list, count or guess the other's rows, including through search and exports.
- Tenant-supplied credentials (their own SMTP mailbox, their own Twilio number) are encrypted at rest and never returned by the API.

## AI and voice agents

The pattern from a production voice-agent app (phone number with Telnyx or Twilio, calls run by a voice platform such as Retell, an LLM for thinking, a TTS voice):

- **Tools are API operations.** When the agent checks a diary, books an appointment or looks something up mid-call, it calls your API with a token scoped to that tenant and those operations. Prefer the API over a workflow tool for anything the conversation waits on; latency matters and the rules stay testable.
- **After the call:** the platform's webhook (transcript, recording, outcome) is signature-verified, stored idempotently by call id, then processed by a job: score the answers, create or update the lead, schedule follow-ups.
- **Knowledge search:** embed each tenant's documents with the provider's embedding model and store vectors in Postgres (pgvector) with the tenant id; retrieval filters by tenant before similarity.
- **Prompts, agent configs and voice settings** are versioned in the repo and pushed to the platform by a script, per environment.
- **Record usage and cost** per call and per tenant (minutes, tokens, TTS characters, SMS) so billing and margins are real.
- **Recordings and transcripts are personal data:** retention period, access by role, scrubbed from error reports.
- **Test with recorded fixtures:** replay stored webhook payloads in e2e tests; keep a small set of scripted test calls for beta.

## Alternative host: Docker on one server

Some apps need long-running Node processes, websockets or a framework server (Next.js with a Node runtime). Then a Docker server behind Traefik (TLS certificates, basic protection) is a fine choice. If you pick it:

- It is a single point of failure; keep backups and files off the box (R2), and document a rebuild from scratch.
- Deploy from CI on merge, then run automatic checks against the live site, same as the Workers flow.
- Keep the beta-first rule: a beta container and database, promote after it soaks.
- The API-first and portable-Postgres rules still apply; the browser still never talks to the database.

## Architecture page

Keep `docs/architecture.md` in plain language using `templates/architecture.md`: what it is built with (a bullet per concern), how the main user journey flows through it as numbered steps, and where it runs and how changes go live (server or platform, deploy trigger, checks before and after). Verify it against the code and the live environments; update it in the same change that adds or removes a service.

## Secrets

- Live in `.env` (git-ignored) locally and in Wrangler secrets per environment. Scripts read them; agents never print them.
- Redis credentials live only with the gateway module's Worker (and the hydration job).
- Deploy tokens are scoped to one account and the permissions the scripts need (Workers, Pages, R2, Hyperdrive, DNS).

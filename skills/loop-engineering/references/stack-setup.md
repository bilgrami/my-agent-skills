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
- Duplicate migration versions: none.
- No secrets in `VITE_` variables.

## Secrets

- Live in `.env` (git-ignored) locally and in Wrangler secrets per environment. Scripts read them; agents never print them.
- Deploy tokens are scoped to one account and the permissions the scripts need (Workers, Pages, R2, Hyperdrive, DNS).

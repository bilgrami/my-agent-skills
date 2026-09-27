# Shipping: beta first, prod by promote

One front door (for example `./scripts/ship.sh`) reading `deploy/environments.toml`. Every command supports `--dry-run`, and `status` shows what is deployed where.

## Ship to beta

`./scripts/ship.sh "message" <explicit paths>`

1. Commit the named paths on the `beta` branch (never blanket staging).
2. Run the local checks: types, tests, API-first guard, generated-file freshness.
3. Push beta.
4. Migrate the beta database and record each migration in history.
5. Deploy the API, then the web app (API first, always).
6. Smoke test beta: every page loads, `/health?deep=1` passes, the CSP names no database or storage host, unsigned file links are refused, admin sites redirect to Access.
7. Record the deploy (commit, time, environment) in a deploys table.
8. Verify the effect of each migration with a query, not the tool's exit code.

## Promote to prod

`./scripts/ship.sh promote prod`, with three gates before anything changes:

1. **Soak:** the beta commit has run on beta for `soak_hours` (24 by default). An emergency flag skips it, and using it is an owner decision.
2. **Beta smoke** passes again.
3. **Rehearsal:** the pending migrations run on prod inside a transaction; prod's schema fingerprint is compared with beta's; then everything rolls back. Any difference stops the promote.

Then the owner types the environment name to confirm, and the script: migrates prod for real, deploys the prod API, fast-forwards `main` to the beta commit, deploys the prod web app, and smoke tests prod.

## Demo

Demo follows beta's code with its own database seeded with fake schools, users and data. A reseed script resets it. Prospects get time-limited invites. Real user data never enters demo.

## Rollback

- Web and API: redeploy the previous commit (Pages and Workers keep versions).
- Database: migrations are additive, so rolling code back does not require rolling schema back. A destructive change ships in two steps (stop using, then drop in a later release).

## Owner actions

Prod promotes, emergency soak skips, secret changes, new accounts or paid plans, DNS and security settings. The agent prints the exact command and waits.

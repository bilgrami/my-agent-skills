# Lessons learned

Each rule is stated as the thing that would have prevented a real incident on a production app built with agents, with the incident in a line or two so the rule stays believable. Read the section that matches what you are touching.

## Verification

**Run the repo's own verify script, never a hand-rolled one.** The root `tsconfig.json` was a solution file with `"files": []`, so a bare `tsc --noEmit` checked zero files and passed on anything. A release went out "green" and the deploy failed on the one file it had just added. Vite strips types rather than checking them, so the build did not catch it either. Make `build` run `verify` first so a type error or red test cannot reach a deploy.

**A gate is real only if you have seen it fail.** Break each gate on purpose once (a type error, a failing test) and confirm the build stops.

**A test file that cannot be imported is worse than no test.** One suite imported a deleted module and collected zero tests for eleven days while still counting as a test file. Another "passed" vacuously because its mock threw on every call and the test asserted the fallback. If you delete a module, grep the tests for it.

**"Fixed in the repo" is not "fixed".** The repo's validator was correct for weeks while the deployed worker still ran the old one. Every fix names which side of the deploy boundary it lands on, and "fixed" carries the deploy that makes it true.

**Audit the live system before trusting the audit.** A forensics pass concluded a secret "was never provisioned" from reading the repo; one query showed it had existed for weeks. Anything that depends on out-of-band state (secrets, flags, applied migrations, deployed versions) is confirmed live before it becomes an action item.

**A design mock is not the live row.** An agent advised a click based on a mockup that showed content the real record did not have, and the job died. Before advising any action whose success depends on data, read that data.

**The check that annoys you is usually measuring something real.** Before overriding a check, read its code. If the check truly is wrong, fix it for everyone rather than skipping it for yourself.

## Database and migrations

**Replay-safe or it takes the others down.** Migration tools replay any file they have no history for. An `INSERT` without `ON CONFLICT DO NOTHING` aborted a whole push on replay and left the migrations behind it unapplied while history claimed otherwise. Every backfill needs a `NOT EXISTS` guard.

**Version numbers are a race with parallel agents.** Two sessions minted the same version within hours; renamed, it collided again. Worse, if the remote ledger already has your version under someone else's file, the tool says "up to date" while your file never ran. Pick the highest version at commit time, recheck at push time, and verify the effect with a query.

**Never share a version number between two files.** The version is the primary key of the history table, so the second file can never be recorded and shows as pending forever. Check for duplicates before adding a migration.

**Build test fixtures from the real DDL, not the spec.** A migration was "verified" against a local stub built from a TDD sentence describing a key/value table; the real table was a singleton row with named columns, and prod failed. `sed` the real `CREATE TABLE` into the fixture.

**Generated types lie when stale.** A migration died on a column the generated types swore existed. For anything a migration writes, `information_schema` is the authority.

**`FOR ALL USING (...)` with no `WITH CHECK` is an open INSERT.** Postgres reuses `USING` as the check, so an admin policy let any admin insert themselves as super admin with one request from the browser. Write separate INSERT/UPDATE/DELETE policies with explicit `WITH CHECK`. RLS does not stop a SECURITY DEFINER function; guard sensitive tables with a trigger too.

**A JSON literal in SQL is single- or dollar-quoted.** `"{...}"::jsonb` is a quoted identifier and aborts the push at that file.

**A trigger that returns NULL means the row was not inserted.** `INSERT ... RETURNING id` then gives NULL, and returning `ok: true` makes the caller wait for work that never existed. Branch on the null.

**One source of truth for derived lookups.** Four hand-copied "current revision" queries drifted apart silently. Use one view or function.

**Views and RPCs the app reads must beat the statement timeout.** Correlated subqueries over 300k rows took 7 seconds and died; aggregate once and join took 0.15. An RPC that does a whole book in one statement is a sizing bug: chunk it by real ids or page numbers, never by `count(*)`.

**No version prefix may be the start of another** (`20251207_` beside `20251207000002_`). `_` sorts after digits, so the tool walks them in the wrong order and reports a version as missing. One repo renamed 61 files to undo letter suffixes and shared prefixes.

**Never accept `migration repair --status reverted` as a fix for a history mismatch.** The CLI suggests it; it unmarks history and the next push reruns every file against production. When migrations reach prod by more than one route, history will disagree; replay-safe files make that harmless.

**End every migration with one verification query** that UNIONs its checks into a single result, so applying it prints proof that it worked.

**Migration numbers are facts, not plans.** Numbering follows what actually shipped; the doc trail absorbs the difference. Never renumber applied history.

**Catch secrets before they are committed.** A pre-commit secret scan, lint, type and unused-code check on staged files is cheap; a leaked key in history is not.

**Database tests run against a real Postgres copy**, not mocks. Mocks agreed with the code; the database did not.

**Loose SQL files in the repo root are drift.** One repo collected dozens of `fix_*.sql`, `RUN_ME_*.sql` and schema dumps next to its migrations; nobody could say which had run where. Database changes are migrations or audited repair scripts, nothing else.

**Data repairs are data, and reviewable.** The pattern that worked: a read-only script decides what to fix, writes the fix as SQL applied in one transaction, a CSV of every decision with its evidence, a CSV of what it could not decide for a person, and an undo script. A stalled pipeline run was healed the same way, by repairing the rows the pipeline reads, idempotently, keyed to the defect.

## Redis

**Redis may not be reachable the way its connection string suggests.** A managed Redis host was not DNS-resolvable from the job runners or dev machines; the credentials in `.env` looked usable and were not, and every "quick" debug script with a direct client failed with `ENOTFOUND` or a dead socket. Every command went through one HTTP gateway from then on.

**A connection cached per isolate leaks.** Serverless keeps many isolates warm, each holding an idle connection, until the provider's max clients runs out. Open per request, or use an HTTP API.

**`FT.CREATE` is a no-op on an existing index.** A new field written to the hashes was invisible to queries, silently. Reconcile with `FT.INFO` and `FT.ALTER`, then rehydrate in full.

**Escape dashes in TAG filters.** A UUID in `@ids:{...}` without backslash-escaped dashes returns nothing and no error.

**Ship the code the scheduled job actually runs.** An hourly hydration job ran a committed bundle; changing the source without rebuilding and committing the bundle silently changed nothing.

**A silent mock is a lie.** The app's Redis service defaulted to an in-memory mock while the docs quoted sub-10ms search and "90% fewer queries" as if measured. A fallback logs loudly, is refused outside dev, and docs label targets as targets.

## API and contracts

**Retrofitting API-first is brutal; start with it.** One app went live Supabase-direct and a year later still had over a thousand direct calls in hundreds of files, tracked by a CI ratchet. The app built API-first from day one holds that count at zero with a lint rule and a CI script.

**A URL parameter is a contract; grep the consumer before writing the producer.** A new page built links with `?lang=` when the reader reads `?textLang=`, and every translation link opened the wrong language for three weeks. One named constant or one shared builder.

**A lossy remapping between DB and UI is a slow lie.** A service remapped rows to camelCase and dropped three columns; the admin drawer fell back to defaults and showed wrong billing values. Ship the raw row (spread, then decorate) or type the mapping so a dropped column is a compile error.

**A foreign-key embed needs a foreign key.** Every invoice read embedded a table linked by a polymorphic id with no FK, so the query layer refused it in prod. A CI check can compare embeds against the FKs migrations create.

## Background jobs and paid work

**Health is what a job produced, not what it claimed.** Workers exit 0 when they find nothing to do; 122 jobs were marked done and billed having produced nothing. Completion counts real output rows before accepting done. Partial success throws so the job retries and resumes.

**New job kinds register everywhere at once.** A kind must be claimable, runnable and countable in the same change. An unregistered kind falls through to "produced 0 rows" and dead-letters; this happened six times. Restate SQL functions from the live definition (`pg_get_functiondef`), never from an old migration.

**Size units of work to the time limit.** A whole-book audio job could never finish inside the 60-minute kill, on any provider. Switching providers just spends more money failing the same way. Chunk it.

**A failed predecessor blocks its dependents, and "queued forever" usually means a dead predecessor.** Check the other jobs in the group before re-diagnosing the worker.

**Never attribute system work to a user.** A backfill written with the book owner as creator would have billed three users for our own cleanup.

**Paid stages run only through the queue.** A stage run from a shell skips the billing path: money spent, nothing recorded, the daily cap unaware.

**Max tokens is thoughts plus answer.** A 500-token answer with a 4,000-token budget came back empty on three models because thinking used it all. Budget an order of magnitude over; an empty answer throws naming the provider's reason; log each raw attempt somewhere a person can query.

**Report the signal, not `code ?? 1`.** Every out-of-memory kill looked like "exit 1" for weeks. Capture the signal.

**Node's global fetch dies under sustained upload load.** It multiplexes over one HTTP/2 session; when that dies every request fails instantly, retries included. Bulk uploads use `node:https`.

## Fly.io and long-running workers

**Undersized machines fail as "script errors".** Jobs on a 256 MB machine were OOM-killed and logged as `exit 1` for weeks. Measure memory under a real job, and log the signal.

**`fly machine run --entrypoint` appends the image's CMD.** A one-off script received the worker's own arguments. Parse args defensively and pass `--restart no` for one-shot machines, or a failure restart-loops.

**The image is your working tree, the schedule runs the bundle.** An uncommitted script change still shipped in an image, while an hourly machine ran a committed bundle that nobody rebuilt, so a source fix silently did nothing. Deploy from a clean checkout and rebuild bundles in the same commit.

**Fly deploys are owner actions.** Agents print the exact `fly deploy` and `fly secrets set` commands; the owner runs them. A deploy from a half-finished tree is a production incident.

**Node's global fetch dies under sustained upload load on long-running workers** (see Background jobs). Use `node:https` for bulk uploads.

## Security

**Fail closed, loudly, and scoped.** A secure cache failed closed correctly but swallowed key errors in a bare `catch` and applied the strictest level to every item. Result: a platform-wide caching outage with no signal. Warn loudly once, and protect only what needs protecting.

**Money is granted only by the server after the provider's proof.** Never a client path that writes payments or balances. Finance actions are role-checked in the database, not by hiding buttons.

**The database trusts one issuer.** Only tokens the API signs. No client gets a route to the database or storage directly, and the CSP says so.

## Product and UX

**Never gate a capability on something the user can do without.** A user outside any club could not write at all because one leg of the feature needed a club. Skip the dependency, name it, do not charge for stages with nowhere to land, and remove the requirement everywhere (a second copy of the rule lived in a boolean column no grep found).

**A disabled control says why, and a refusal that knows the reason shows it.** The server returned a list of exact problems; the client showed "something is missing".

**A UI that cannot see the queue teaches people the queue is broken.** Any screen that enqueues work shows its lifecycle and renders a dead job's reason in plain words.

**Never state a figure the data does not hold.** Generated reports and letters leave a marked gap for a person rather than a plausible number, above all for counts of people.

**Anything in `public/` is public.** Help images and screenshots are drawn with invented data; a real name or amount there is one URL from anyone.

**Help moves with the screen.** A change to a screen updates its help page in the same batch; tests fail if help points at a screen, image or related page that no longer exists.

**Designs are approved before they are built.** Review mockups in the app with named approvers; changing the design bumps its version and resets approval.

**Bump the version on every shipped change.** The footer reads it; if it does not move, nobody can tell which build they are looking at.

**Remembered state that changes what a spend button does is named next to the button**, with a one-click way out.

**Retiring a surface means rehoming its furniture.** Blocking phones from one screen silently removed the only report button on mobile. Inventory every affordance that lives only there first.

**Cut human-visible text at word boundaries.** `left(slug, 60)` shipped "...-to-the-w".

**Invalid CSS is a silent no-op, and comments age into lies.** A gradient routed into `background-color` was dropped without error. Test with the real values the code path carries; turn invariant comments into assertions.

**Never force color onto content that paints its own page.** Overrides may neutralize dimming, never recolor.

## Agent sessions

**One folder per piece of work.** `agents/<date>-<task>/` with `plan.md`, `progress.md` (newest first) and `agents.md` (how to work here, owner rules, delivery flow). The next session starts from the newest folder.

**Keep the repo root clean.** One repo accumulated hundreds of timestamped config copies and scratch scripts in its root. Scratch goes in a git-ignored folder.

**Know the sandbox's limits.** In the cloud sandbox each shell call is its own process namespace: background processes die when the call returns, and one call lasts about three minutes. A full typecheck or test run on a big repo may not fit; run in chunks and say that is what you did. Start a dev server and its test in the same call.

**A beta that shares the prod database only tests screens.** One app's beta and live sites shared a database, so beta could not safely try data changes. Give beta its own database from the start.

**Owner actions are named, not taken.** Deploys to prod, secret changes, paid reruns, account and billing changes: print the exact command and let the owner run it.

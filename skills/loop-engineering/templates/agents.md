# Agent notes: how to work in this repo

Read this before starting. It is how the last session worked, and the owner's rules.

## Product and stack
Brand, domains, what runs where (web, API Worker, jobs Worker, database per environment, buckets).

## Owner rules
- Plan first for any new requirement; wait for approval.
- Stage explicit paths only.
- Never print secrets; read `.env` only inside scripts.
- Owner actions: <list>.
- Writing style: <e.g. no em dashes, plain language>.

## Delivery workflow
How changes reach the repo (direct commit, bundle, archive), how to migrate, deploy and smoke test each environment.

## Checks before handing over
The exact commands, in order.

## Where things live
Contract, gateway, web app, migrations, SQL tests, plans.

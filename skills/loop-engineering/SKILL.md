---
name: loop-engineering
description: Plan-first build loop for new features on a Cloudflare + Clerk + API-first stack. Use when starting a new feature, app or phase of work that should be planned, approved, then built and tested phase by phase.
---

# Loop Engineering

A plan-first, test-gated build loop. Nothing gets built until the plan is approved. Each phase is implemented, tested and reviewed before the next one starts.

## Model roles

Split work so the model reviewing code is never the one that wrote it.

- Planner and reviewer: Opus 5.5 at high effort for Phase 0 and plan critique, medium for in-loop reviews.
- Builder: Fable 5.1 (swap roles if the other model does better on this codebase).
- Reviews always run in a separate agent with fresh context, not as self-review in the builder's context.

## Stack rules (defaults, override per project if the user says so)

- Hosting: Cloudflare. API on Workers (Hono), sites on Pages. Environments: dev (local), beta, demo, prod. Each has its own wrangler env, secrets, database and Clerk instance. Never share secrets across environments.
- Demo runs on seeded, resettable fake data. Never real user data.
- API first. The OpenAPI spec is the source of truth; generate TypeScript types and the client from it. Version everything under /v1. Use one error envelope shape everywhere.
- No direct Supabase. Frontends never hold a Supabase key. Only the Worker talks to Postgres (via Hyperdrive). All data flows through the API.
- Auth: Clerk with custom branding and a custom domain. The Worker verifies the Clerk JWT on every request. Sync users via Clerk webhooks and verify their signatures.
- Validate all input with zod. Set CORS per environment. Rate limit public endpoints.
- Every service exposes /health. Log errors with request IDs.

## Phase 0: Plan (no code until the user approves)

For every new feature, produce:

1. Feature breakdown: features, then phases. Each phase must be shippable and testable on its own, with a written Definition of Done.
2. Mocks: UI mockups for each screen, plus MSW API mocks so frontend work can start before the API exists.
3. API design: resources, endpoints, request and response schemas, errors, auth rules, pagination. Written as OpenAPI.
4. API docs generated from the spec.
5. Data model and migrations, with a rollback for each.
6. Unit test plan and e2e test plan, mapped to each phase's Definition of Done.
7. Risks and open questions.

Then:

- Self-critique the plan: missing edge cases, auth gaps, error states, empty states, environment differences, anything untestable. Fix the gaps.
- Have a separate reviewer agent critique it again with fresh context. Fix what it finds.
- Ask the user clarifying questions (use AskUserQuestion when available).
- Wait for explicit approval before writing any code.

## Build loop (per phase)

1. Write the phase's unit and e2e tests first, from the plan. Confirm they fail.
2. Implement the phase.
3. Run gates in order: typecheck, lint, unit, build, e2e (Playwright, using Clerk testing tokens, against a local or preview deploy).
4. If anything fails: find the root cause, fix, rerun. Max 3 attempts per failure. After that, stop and report what was tried.
5. Never skip, weaken or delete a test to make it pass. If a test looks wrong, stop and explain why.
6. When all gates are green, a reviewer agent checks the diff against the plan and the Definition of Done. Fix any gaps it finds and rerun the gates.
7. Update PROGRESS.md: phase status, decisions, deviations from plan, known issues. Commit with explicit file paths (never `git add -A` or other blanket staging).
8. Deploy to beta automatically and run a smoke test against it.
9. Move to the next phase and repeat.

PROGRESS.md is the resume point. At the start of any session, read it first and continue from the last incomplete phase.

## Stop and ask the user before

- Any change to the approved plan or API contract
- Schema migrations that touch existing data
- Anything destructive (drops, deletes, force pushes)
- Deploying to demo or prod
- Adding a new dependency or third-party service

## Done means

All phases green, docs match the code, PROGRESS.md is current, and a short report covers what shipped, what deviated from the plan, and what is left.

## Style

No em dashes in any output. Write plans and reports in plain prose, not robotic checklists, where it reads better.

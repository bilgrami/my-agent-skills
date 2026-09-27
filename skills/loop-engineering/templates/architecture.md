# Stack and architecture

One or two sentences on the shape: what the product is and where it runs. Say it was checked against the current code and live environments, and when.

## What it is built with

- **Website and dashboard:** framework, language, where it is hosted.
- **API:** where it runs, how it is versioned.
- **Database:** host, where the business rules live, how tenants or users are kept apart.
- **Sign-in:** provider, how accounts and organizations map to customers.
- **Files:** store and how files are served.
- **Cache, search, queues:** what and why.
- **Automation:** workflow tool, where it runs, what it handles, where its workflows are tracked.
- **Outside services:** messaging, voice, AI models, calendar, email; one line each.
- **Billing:** provider.
- **Error tracking:** tool, and how personal details are hidden.
- **Backups:** what, how often, where, and when a restore was last tested.

## How <the main journey> flows through it

1. The first thing a user or outside system does.
2. Which service receives it and what it calls.
3. What gets stored where.
4. What happens afterwards in the background.
5. What the user sees.

## Where it runs and how changes go live

- **Environments:** beta, demo, prod, with addresses.
- **Going live:** what triggers a deploy, the order (API before web), how migrations are applied.
- **Checks before a change is saved:** secret scan, lint, types, unused code.
- **Tests on every change:** unit, screen (e2e), database tests against real Postgres, with rough counts.
- **Checks after a deploy:** smoke tests against the live site.

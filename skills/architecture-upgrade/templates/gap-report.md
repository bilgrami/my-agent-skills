# Architecture gap report: <app name>

<yyyy-mm-dd>. Checked against commit <sha> and the live <environments> (read only).

## Summary

Three to five sentences in plain language: the overall shape, the biggest risks, and what fixing them buys.

| Area | Result |
| --- | --- |
| Shipping and environments | <n findings, worst severity> |
| API-first | |
| Database and migrations | |
| Automation (n8n) | |
| Hosting and resilience | |
| Security and personal data | |
| Tests and checks | |
| AI and voice agents | |
| Observability | |

## Findings

### F1. <short title> (Critical | High | Medium | Low)

- **What:** one or two plain sentences.
- **Evidence:** `path/to/file.ts:42`, config value, or command output.
- **Why it matters:** what goes wrong, for whom.
- **Fix:** playbook name, and the phase it lands in.
- **Status:** open | fixed in <version> | deferred | accepted by owner

### F2. ...

## What is already good

Credit what works, so the plan does not break it.

## Open questions

Things the audit could not confirm read-only, and who can answer them.

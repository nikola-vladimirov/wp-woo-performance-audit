---
name: wp-woo-performance-audit
description: Audit a WordPress or WooCommerce site or codebase for performance, HPOS compatibility and layout risk. Use when inheriting or first-looking at a WordPress or WooCommerce repo, reviewing plugin or theme code for slow queries, caching, cron, AJAX or cart fragments, checking WooCommerce HPOS and cart, checkout or Action Scheduler code, triaging a slow store, preparing a launch or sale, or when the user says "audit this store", "why is the site slow", "performance review", "WooCommerce review", "site audit", "onboarding", "what am I looking at", "pre-launch check" or "layout audit". Called by lean-project for WordPress and WooCommerce work, with the edited files as scope.
---

# WordPress and WooCommerce performance audit

One skill for three jobs: classify an unfamiliar site, review code for performance and HPOS problems, and triage a slow store. It replaces `wp-site-audit-and-onboarding`, `wp-performance-review` and `wp-woocommerce-dev` for performance work. Design judgment stays in `ui-ux-pro-max`, and markup in `wp-theme-development` and `wp-block-development` (see Layout below).

Core principle: classify before judging, scan before reading, and read each finding in context. The scan is a heuristic. A line it flags is a place to read, not a verdict.

## Scope (mandatory)

- **Code review:** only the files the task edited. Pass them to the scan. A folder scan is for a site audit or a user's request for the whole project.
- **Full-project review:** only on the user's request or after the model suggests one for a huge change. Suggest it in one line and wait for a yes.
- Report only findings in the scanned files. Name anything you did not look at.

## Pick a mode

| The user wants | Do | Read |
|---|---|---|
| Understand an unfamiliar repo or site | Classify the stack, map surfaces, route follow-ups | `references/stack-discovery.md` |
| Review code for performance (plugin, theme, companion script) | Run the scan on the scope, then read each hit in context | `references/performance-patterns.md` |
| Review WooCommerce code (cart, checkout, orders, gateways, Action Scheduler, templates) | Scan, then check HPOS and the WooCommerce rules | `references/woocommerce-patterns.md` |
| A store or site is slow | Measure first (see Triage), then trace the slow path in code | `references/performance-patterns.md`, "Triage" |
| Launch, sale or traffic-event readiness | The pre-launch checklist | `references/performance-patterns.md`, "Pre-launch" |
| Look at layout, spacing, hierarchy or shop UX | Route, do not judge here (see Layout) | none |

## Run the scan

```bash
bash "${WP_PERF_AUDIT_HOME:-$HOME/.claude/skills/wp-woo-performance-audit}/scripts/scan.sh" <edited files or folder>
```

Output: `file:line: SEVERITY rule-id: message`, then a count. Rule IDs are listed in `scripts/scan.sh`. `lean-project audit perf <files>` runs the same script when lean-project is installed.

Then read each hit in context. Many are false positives: an admin-only query, a CLI command, a cron job, a value that is already escaped. Drop the ones that do not hold, and say which you dropped and why.

## Severity

| Severity | Meaning |
|---|---|
| **CRITICAL** | Breaks at scale or on HPOS stores (500s, locks, cache bypass on every page, orders read as posts), or a security or card-data failure |
| **WARNING** | Slows the site or cart under load, or is fragile on upgrade |
| **INFO** | Optimization or cleanup |

Do not raise CRITICAL from architecture alone. Raise it when a failure would reach real shoppers or real orders.

## Output

```markdown
## Audit: <target>
Scope: <files or folder, what was out of scope>
Shape: <plugin | theme | block theme | WooCommerce | headless | multisite | builder-heavy>

### CRITICAL
- `path/file.php:42` rule-id. What it does, why it matters, the fix.

### WARNING
- ...

### INFO
- ...

### Route
1. <skill or action> for <reason>

### Not checked
- <what you did not verify, and why>
```

Keep each finding to one or two lines plus the fix. Show a BAD/GOOD pair only when the fix is not obvious.

## Triage: "the site is slow"

1. Measure before reading code. Use Query Monitor or the server's own timing on a staging copy. For the front end, run Lighthouse or PageSpeed on the slow URL, and look at TTFB separately from render time.
2. Find the slow layer: TTFB high means PHP, queries or cache bypass. Render time high means assets, images or layout shift.
3. Check cache bypass first. A `session_start()`, a `setcookie()` on public pages or a cookie set on every visit makes the whole page uncacheable.
4. Then the queries: unbounded queries, meta queries, product queries through `WP_Query`, and the cart and checkout path.
5. Report the measurement with each finding. Without a measurement, say the finding is unproven.

## Pre-launch

Run the checklist in `references/performance-patterns.md`. The short version: a page cache that works for anonymous users, object cache on, no unbounded queries, cart fragments limited to shop pages, cron on a server schedule, payment and webhook paths tested on staging, and load tested at the expected peak.

## Layout

This skill does not judge design. Route:

- Visual hierarchy, spacing, typography, contrast, shop and checkout UX: `ui-ux-pro-max`.
- Whether the layout is built right (theme.json, template hierarchy, template parts, hardcoded styles): `wp-theme-development`.
- Block markup and render output: `wp-block-development`.
- Keyboard, focus, labels and contrast in code: `wp-accessibility-review`.

Layout problems that cost speed (layout shift from late-loaded fonts or images, oversized images, too many blocking styles) are performance findings. Report them here with the measurement.

## Called from lean-project

lean-project routes WordPress and WooCommerce work here:

- A phase or card that changes WordPress or WooCommerce code runs the scan on the card's files, after `lean-project audit security`.
- A full audit is a separate task with its own scope, not part of every card.
- Findings go on the card or in the phase's acceptance notes. Do not move the card to `done` while it has an open CRITICAL finding.
- Record in the plan which mode ran, which files were scanned and the counts.

A lean-project session that needs only the scan does not need to read the reference files. Read one only when its finding needs context.

## Working rules

- Verify against current docs when a finding depends on a version: WordPress and WooCommerce changelogs, the WooCommerce HPOS docs and the Action Scheduler docs. Note the URLs in the output.
- This skill does not do PCI compliance, hosting setup or store configuration. Code-level payment safety only (no raw card data stored or logged, HTTPS check, tokenization).
- Keep it short. Read the reference file for the mode you are in, not all three.
- Follow the user's own CLAUDE.md and memory rules first.
- End the reply with one line on what you skipped and one on the main risk, as ponytail mode asks.

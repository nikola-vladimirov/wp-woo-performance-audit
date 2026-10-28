# wp-woo-performance-audit

A Claude Code skill for auditing WordPress and WooCommerce sites and code: performance, HPOS compatibility, cart and checkout, and a first look at an unfamiliar store.

It merges three skills into one: `wp-performance-review`, `wp-woocommerce-dev` and `wp-site-audit-and-onboarding`. Layout and design judgment stay in other skills, which the skill routes to.

## What it does

- **Site audit.** Classifies the stack (plugin, theme, block theme, WooCommerce, headless, multisite, builder-heavy), maps the surfaces, and names the next review in order.
- **Code review.** Scans PHP and JS for performance problems: unbounded queries, `query_posts()`, `session_start()`, cache-busting cookies, remote calls with no timeout, cron without guards, polling, and more.
- **WooCommerce review.** HPOS declaration and CRUD use, product queries, cart fragments, Action Scheduler, sessions, template overrides, and code-level payment safety (never store or log card data, verify webhook signatures). Not a PCI audit.
- **Triage and pre-launch.** A measure-first path for a slow store, and a checklist before a launch or sale.

## Install

In Claude Code:

```
/plugin marketplace add nikola-vladimirov/wp-woo-performance-audit
/plugin install wp-woo-performance-audit@wp-woo-performance-audit
```

The skill can also be copied by hand into `~/.claude/skills/wp-woo-performance-audit` (the folder with `SKILL.md`, `references/` and `scripts/`).

## Use

Ask Claude for an audit, for example "audit this store for performance", or "review these edited files for WooCommerce issues". Claude runs the scan on the scope you give (the edited files, or a folder when you ask for a full audit), then reads each hit in context.

Run the scan yourself:

```bash
bash skills/wp-woo-performance-audit/scripts/scan.sh path/to/file.php path/to/other.js   # from the plugin folder
```

Output is `file:line: SEVERITY rule-id: message`, then a count. Each hit is a line to read, not a verdict.

## Works with lean-project

[lean-project](https://github.com/nikola-vladimirov/lean-project) routes WordPress and WooCommerce work here. Its `lean-project audit perf <files>` command runs `scripts/scan.sh` from the installed plugin for the card's edited files, and a CRITICAL hit keeps the card from `done` until it is fixed or explained. lean-project's WordPress guide points to this skill for deeper audits.

## Tests

```bash
bash tests/run.sh
```

The tests write a bad fixture and a clean fixture, check that every rule fires on the bad one, that the clean file gets no hits, and that a folder scan skips `vendor/`.

## Limits

- The scan is a heuristic. Calls and checks that span up to a few lines are read together, but a check made far from its call (for example a guard in another function) is still missed. Read each hit.
- Hits in admin, CLI, cron or test paths are marked lower risk. Those paths do not face shoppers, but check the context before dropping a hit.
- It does not measure speed. Use Query Monitor, Lighthouse or PageSpeed for numbers.
- Version-dependent rules (HPOS, session caps, deprecations) are checked against the WooCommerce version you name in the findings. Check the changelog for your store's version.

## Rule list

Every rule in the reference files is in `scripts/scan.sh` (35 rules, plus file-level checks for HPOS declaration, webhook signatures and template hooks). Rule IDs appear in each finding.

## License

MIT. See [LICENSE](LICENSE).

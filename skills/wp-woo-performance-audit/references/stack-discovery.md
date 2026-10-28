# Stack discovery

Use for a first look at a repo or site. Classify, map the surfaces, name the risks, route. Do not review every file in one pass.

## 1. Set the target

Entire repo, one plugin, one theme, a `wp-content/` subtree, or a monorepo where WordPress is one surface. Write down what is out of scope.

## 2. Classify

| Shape | Signals |
|---|---|
| Plugin | plugin header (`Plugin Name:`), `register_activation_hook`, `mu-plugins/`, CPTs, admin pages |
| Classic theme | `style.css` header, `functions.php`, `template-parts/`, no `theme.json` |
| Block theme | `theme.json`, `templates/`, `parts/`, `block.json` in blocks |
| WooCommerce | `woocommerce/` template overrides, `declare_compatibility`, `WC_Payment_Gateway`, cart and checkout hooks |
| Headless | a frontend app folder, WPGraphQL, revalidation or preview webhooks |
| REST-heavy | `register_rest_route()`, `permission_callback`, external integrations |
| Content-model heavy | `acf-json/`, `register_post_type`, `register_taxonomy`, many `meta_query` |
| Multisite | `is_multisite()`, `switch_to_blog()`, network admin code |
| Composer-managed | `composer.json`, `web/`, `config/application.php` (Bedrock) |
| Builder-heavy | Elementor, Divi, WPBakery, Beaver Builder, Bricks, shortcode lock-in |

Give a primary shape and any secondary ones.

## 3. Search

These commands classify a repo quickly. Each finding is a signal, not a verdict.

```bash
grep -rnE "Plugin Name:|register_activation_hook|register_uninstall_hook" . --include=*.php
grep -rnE "theme\.json|Template Name:|add_theme_support\(|after_setup_theme" . --include=*.php --include=*.json
grep -rnE "block\.json|registerBlockType|useBlockProps|InnerBlocks" . --include=*.json --include=*.js --include=*.jsx --include=*.ts --include=*.tsx --include=*.php
grep -rnE "woocommerce|WC_|FeaturesUtil::declare_compatibility|action_scheduler" . --include=*.php --include=*.js --include=*.md --include=*.yml --include=*.yaml
grep -rnE "acf-json|acf_add_local_field_group|register_post_type\(|meta_query" . --include=*.php --include=*.json
grep -rnE "register_rest_route\(|permission_callback|graphql|revalidate|webhook" . --include=*.php --include=*.js --include=*.ts --include=*.md
grep -rnE "dbDelta\(|CREATE TABLE|ALTER TABLE" . --include=*.php
grep -rnE "phpunit|playwright|cypress|phpstan|phpcs|eslint" . --include=*.php --include=*.xml --include=*.json --include=*.js --include=*.ts --include=*.yml --include=*.yaml
```

Do not dump raw listings. Summarize into components.

## 4. Look for risk signals

Flag these early. Calibrate severity, do not inflate it.

- Several custom plugins that overlap (routing, checkout, content model).
- Custom SQL, custom tables or upgrade routines (route to a migration review).
- Custom REST, GraphQL or auth code.
- WooCommerce checkout, order, payment or webhook code, especially without tests.
- Build output committed without a source folder or script.
- Large ACF or meta-query dependence.
- Multisite assumptions in code that runs on one site.
- Release or deploy scripts with no rollback or environment notes.
- No tests, no static analysis, no local or dev docs.

## 5. Route

| Finding | Next review |
|---|---|
| Custom plugin architecture | the plugin's own review (architecture, hooks, i18n) |
| Theme or block markup, theme.json | `wp-theme-development`, `wp-block-development` |
| Store performance or HPOS | this skill, `woocommerce-patterns.md` |
| Query, cache or cron performance | this skill, `performance-patterns.md` |
| Security | `wp-security-review`, or `lean-project audit security` |
| REST routes | `wp-rest-api-development` |
| ACF, CPT or taxonomy design | `wp-acf-and-content-modeling` |
| Headless or WPGraphQL | `wp-headless-and-wpgraphql` |
| WP-CLI or multisite operations | `wp-wpcli-and-ops` |
| Migrations, dbDelta, schema | `wp-migration-upgrade-review` |
| Deploy pipeline | `wp-ci-cd-and-release-engineering` |
| Static analysis setup | `wp-phpstan-review` |
| Layout, design, shop UX | `ui-ux-pro-max` |

## 6. Prioritize and report

- **Immediate:** where the next audit starts.
- **Secondary:** important, not first.
- **Context:** architecture notes that are not problems.

Use the output format in `SKILL.md`. Finish with **Residual unknowns**: what the files could not show, such as which plugins are active in production, whether committed build output matches the source, whether multisite is really on, and which external services exist.

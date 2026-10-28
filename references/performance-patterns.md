# Performance patterns (WordPress code)

Read the section for the mode you are in. Rule IDs match `scripts/scan.sh`. Hits in admin, CLI, cron or test paths are marked lower risk.

## Severity

| Severity | Meaning |
|---|---|
| CRITICAL | Fails at scale: OOM, 500s, DB locks, cache bypass on every page, self-DDoS polling |
| WARNING | Slows pages or the cart under load |
| INFO | Optimization |

Context lowers risk. Admin-only code, CLI commands and cron jobs do not face public traffic, so `posts_per_page => -1` there is INFO at most.

## Queries

| Rule | Severity | Problem | Fix |
|---|---|---|---|
| `query-unbounded` | CRITICAL | `posts_per_page => -1` or `numberposts => -1` on a public path | Cap it, paginate, or cache the ID list |
| `query-posts` | CRITICAL | `query_posts()` breaks the main query | `WP_Query`, or `pre_get_posts` for the main query |
| `query-n-plus-one` | CRITICAL | Query, `get_post_meta` or remote call inside a loop | Prime the cache (`update_post_meta_cache`), or fetch once before the loop |
| `query-like-lead` | WARNING | `LIKE '%term%'` scans the whole table | Trailing wildcard, or a search index |
| `query-meta-value` | WARNING | `meta_query` on `value` for a binary flag | Store presence of a key instead |
| `query-no-found-rows` | INFO | Count query when there is no pagination | `'no_found_rows' => true` |
| `query-post-not-in` | WARNING | Large `post__not_in` | Positive `post__in`, or a precomputed list |

## Hooks, options and cache

| Rule | Severity | Problem | Fix |
|---|---|---|---|
| `session-start` | CRITICAL | `session_start()` on the front end makes the whole site uncacheable | Remove it, or start a session only where needed |
| `cookie-public` | WARNING | `setcookie()` on public pages makes those pages uncacheable per visitor | Set cookies only when the user acts |
| `option-write` | INFO | `update_option()` or `add_option()` | Confirm it is not on page load |
| `transient-dynamic` | WARNING | Per-user or dynamic transient keys fill `wp_options` without a persistent object cache | `wp_cache_set()` with a group, or check `wp_using_ext_object_cache()` |
| `uncached-lookup` | INFO | `url_to_postid()`, `attachment_url_to_postid()`, `count_user_posts()` | Wrap in an object cache |
| `in-array-loose` | WARNING | `in_array()` without strict `true`, O(n) | Strict comparison, or `isset()` on a map in hot loops |
| `remote-no-timeout` | WARNING | `wp_remote_get/post` with no `timeout` (default 5 s), no error check | Set `timeout`, check `is_wp_error()`, cache the result, or move it to cron |
| `remote-file-get` | WARNING | `file_get_contents()` on a URL | `wp_remote_get()` with a timeout |

## Cron

| Rule | Severity | Problem | Fix |
|---|---|---|---|
| `cron-unguarded` | WARNING | `wp_schedule_event()` with no `wp_next_scheduled()` guard creates duplicates | Guard it |
| `cron-long-job` | WARNING | One cron run loops over all users or posts | Batch with `wp_schedule_single_event()` and an offset |

On busy sites, run cron from the server: `define( 'DISABLE_WP_CRON', true );` and `wp cron event run --due-now` every minute.

## AJAX, JS and assets

| Rule | Severity | Problem | Fix |
|---|---|---|---|
| `ajax-polling` | CRITICAL | `setInterval` with `fetch` or `ajax` | Event-driven updates, or long intervals with backoff |
| `ajax-post-read` | WARNING | `$.post()` for a read bypasses cache | GET, with a cacheable response |
| `lodash-full` | WARNING | `import _ from 'lodash'` bloats the bundle | Import the one function you need |
| `enqueue-global` | WARNING | Scripts and styles load on every page | Enqueue where used, or dequeue per template |
| `asset-no-version` | INFO | `wp_enqueue_*` without a version | Pass the version, or `filemtime()` |

## Editor and blocks

- Heavy data fetching or preview logic in the editor slows the editor load.
- `wp_kses_post()` in a render callback can break InnerBlocks.
- Broad imports bloat the editor runtime.

## Layout and front-end speed

These count as performance findings when measured:

- Images without width and height, or oversized for their slot (layout shift, bytes).
- Web fonts loaded late or without `font-display`.
- Above-the-fold styles blocked behind large stylesheets.
- Late-injected banners or widgets that push content down.

Measure with Lighthouse or PageSpeed on the URL, and cite the metric (CLS, LCP, TBT).

## Caching and hosting

- **Managed hosts** often provide an object cache and platform helpers (for example `wpcom_vip_*`). Check the host's docs first.
- **Self-hosted:** add a persistent object cache (Redis or Memcached) and wrap expensive lookups yourself.
- **Shared hosting:** unbounded queries and remote calls fail first. Be strict about them. Do not recommend an object cache that the host does not provide.
- **Cache bypass** from marketing query strings (`utm_*`, `fbclid`) creates a cache miss per URL. Strip them at the CDN or edge.
- **Sitemaps and redirects:** deep archives attract crawlers. Exclude what you do not need and cache the rest. Redirect loops cost CPU.

## Triage order

1. Cache bypass (session, cookies, query strings).
2. Unbounded queries and N+1.
3. Remote calls on page load.
4. Cart and checkout path (fragments, product queries, sessions).
5. Assets and layout shift.

## Pre-launch

- [ ] Page cache works for anonymous users (check a second request returns cached headers).
- [ ] Object cache is on, or the host provides one.
- [ ] No CRITICAL scan findings on the changed code.
- [ ] Cart fragments load only on cart, checkout and product pages.
- [ ] Cron runs from the server schedule.
- [ ] Payment and webhook paths tested on staging with test keys.
- [ ] A load test at the expected peak, watching TTFB and DB time.
- [ ] Rollback plan and a current backup.

## Common false positives

| Pattern | Why it is often fine |
|---|---|
| `posts_per_page => -1` in CLI or cron | Runs off the request path, but still check memory |
| `session_start()` in a CLI or admin-only context | Cache is not involved |
| `in_array()` on a three-item list | Cost is trivial |
| `update_option()` in an activation or upgrade routine | Runs once |
| `set_transient()` with a fixed key | Bounded rows |

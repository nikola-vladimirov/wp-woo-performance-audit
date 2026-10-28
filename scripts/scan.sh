#!/usr/bin/env bash
# Heuristic scan for WordPress and WooCommerce performance and HPOS problems. Read-only.
# Usage: scan.sh <folder>           every PHP and JS file under it (vendor, node_modules, build and .git skipped)
#        scan.sh <file> [file ...]  only those files (the review scope rule)
# Output: file:line: SEVERITY rule-id: message, then a count. Each hit is a line to read, not a verdict.
set -u
export LC_ALL=C

if [ $# -eq 0 ]; then
  echo "usage: scan.sh <folder> | scan.sh <file> [file ...]" >&2
  exit 2
fi

if [ $# -eq 1 ] && [ -d "$1" ]; then
  FILES=$(find "$1" -type f \( -name '*.php' -o -name '*.js' -o -name '*.jsx' -o -name '*.ts' -o -name '*.tsx' \) \
    -not -path '*/vendor/*' -not -path '*/node_modules/*' -not -path '*/build/*' -not -path '*/.git/*' | sort)
else
  FILES=$(printf '%s\n' "$@" | grep -E '\.(php|js|jsx|ts|tsx)$' | sort -u)
fi

# rule <SEVERITY> <rule-id> <extended regex> <message> [regex that clears a hit on the same line]
rule() {
  local sev=$1 id=$2 pat=$3 msg=$4 clear=${5:-@@never@@} f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    grep -nE -- "$pat" "$f" 2>/dev/null | grep -vE -- "$clear" | while IFS= read -r hit; do
      printf '%s:%s: %s %s: %s\n' "$f" "${hit%%:*}" "$sev" "$id" "$msg"
    done
  done <<EOF
$FILES
EOF
}

# files_matching <extended regex>: the scanned files with at least one matching line
files_matching() {
  local f
  while IFS= read -r f; do
    [ -n "$f" ] && grep -qE -- "$1" "$f" 2>/dev/null && printf '%s\n' "$f"
  done <<EOF
$FILES
EOF
}

scan_all() {
  # CRITICAL: breaks at scale, on HPOS stores, or card data
  rule CRITICAL query-unbounded '(posts_per_page|numberposts).{0,20}(=>|,|=) *-1' "unbounded query (-1): cap it, paginate, or cache the IDs"
  rule CRITICAL query-posts 'query_posts[[:space:]]*\(' "query_posts() breaks the main query: use WP_Query or pre_get_posts"
  rule CRITICAL session-start 'session_start[[:space:]]*\(' "session_start(): on the front end this makes every page uncacheable"
  rule CRITICAL ajax-polling 'setInterval.*(fetch|ajax|\$\.)' "request on a timer: a self-inflicted load risk"
  rule CRITICAL hpos-order-posts '(get_posts|WP_Query|post_type).{0,80}shop_order|shop_order.{0,80}(get_posts|WP_Query)' "order read as a post: use wc_get_orders() (breaks on HPOS)"
  rule CRITICAL hpos-order-meta '(get|update|delete)_post_meta[[:space:]]*\([[:space:]]*\$order' 'order meta through post meta: use $order->get_meta() and update_meta_data()'
  rule CRITICAL hpos-wpdb '(wp_posts|wp_postmeta).{0,200}shop_order' "SQL against post tables for orders: use the CRUD APIs"
  rule CRITICAL card-data '(card_number|card_cvv|cvv).{0,80}(error_log|_meta|update_option|insert)|error_log.{0,80}(card|cvv)' "card data stored or logged: never keep card numbers or CVV"

  # WARNING: slows pages or the cart under load, or is fragile
  rule WARNING remote-no-timeout 'wp_remote_(get|post|request)[[:space:]]*\(' "remote call: check it sets 'timeout' (args may sit on the next lines) and checks is_wp_error()" 'timeout'
  rule WARNING remote-file-get 'file_get_contents[[:space:]]*\([[:space:]]*["'\'']https?://' "file_get_contents() on a URL: use wp_remote_get() with a timeout"
  rule WARNING query-like-lead "LIKE[[:space:]]+'%" "LIKE with a leading wildcard scans the whole table"
  rule WARNING query-post-not-in 'post__not_in' "post__not_in with a long list: prefer post__in or precomputed IDs"
  rule WARNING product-wp-query 'post_type.{0,10}product\b' "products through WP_Query: use wc_get_products() or WC_Product_Query"
  rule WARNING in-array-loose 'in_array[[:space:]]*\(' "in_array() without strict true" 'true'
  rule WARNING cron-unguarded 'wp_schedule_event[[:space:]]*\(' "wp_schedule_event(): check wp_next_scheduled() guards it, or it duplicates" 'wp_next_scheduled'
  rule WARNING transient-dynamic 'set_transient[[:space:]]*\([[:space:]]*(\$|[^,]*\{\$)' "dynamic transient key: per-user rows fill wp_options without a persistent object cache"
  rule WARNING ajax-post-read '\$\.post\(' "POST for a read bypasses the cache: use GET if it only reads"
  rule WARNING lodash-full "import _ from ['\"]lodash['\"]" "full lodash import: import the one function you need"
  rule WARNING cookie-public 'setcookie[[:space:]]*\(' "setcookie(): on public pages this can make responses uncacheable per visitor"
  rule WARNING wc-fragments 'wc-cart-fragments' "cart fragments: confirm they load only on cart, checkout and product pages"

  # INFO: optimization and cleanup
  rule INFO uncached-lookup 'url_to_postid|attachment_url_to_postid|count_user_posts' "uncached lookup: wrap it in an object cache"
  rule INFO option-write '(update|add)_option[[:space:]]*\(' "option write: confirm it does not run on every page load"
  rule INFO wc-session 'wc_session_expiration' "session expiration filter: the value must stay at 30 days or less (WC 10.1+)"
  rule INFO wc-enqueue-js 'wc_enqueue_js[[:space:]]*\(' "wc_enqueue_js() is deprecated from WC 10.4: use wp_add_inline_script()"
  rule INFO debug-log 'error_log[[:space:]]*\(' "debug logging left in: remove it or gate it"

  # File-level checks
  local first
  first=$(files_matching 'WC requires at least|Requires Plugins:.*woocommerce|WC tested up to' | head -n 1)
  if [ -n "$first" ] && [ -z "$(files_matching 'custom_order_tables')" ]; then
    printf '%s: CRITICAL hpos-declaration: WooCommerce plugin with no custom_order_tables declaration in the scanned files (check the whole plugin if only edited files were scanned)\n' "$first"
  fi
  files_matching '[Ww]ebhook' | while IFS= read -r f; do
    grep -qE 'hash_hmac|hash_equals' "$f" || printf '%s: CRITICAL webhook-unverified: webhook code with no signature check (HMAC with hash_equals) in this file\n' "$f"
  done
  printf '%s\n' "$FILES" | grep -E '/woocommerce/[^/]+\.php$' | while IFS= read -r f; do
    [ -n "$f" ] && ! grep -qE 'do_action|apply_filters' "$f" && printf '%s: CRITICAL template-no-hooks: template override with no do_action() or apply_filters(): confirm the original template'"'"'s hooks are kept\n' "$f"
  done
}

out=$(scan_all)
[ -n "$out" ] && printf '%s\n' "$out"
count() { printf '%s\n' "$out" | grep -c " $1 "; }
echo "SCAN: $(count CRITICAL) critical, $(count WARNING) warning, $(count INFO) info in $(printf '%s\n' "$FILES" | grep -c .) file(s). Heuristic: read each hit in context before you report it."
exit 0

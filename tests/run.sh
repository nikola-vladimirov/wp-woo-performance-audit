#!/usr/bin/env bash
# Checks scripts/scan.sh: every rule fires on the bad fixtures, the clean file gets no hits,
# multi-line calls are read as one, admin paths are marked lower risk, and a folder scan skips vendor code.
# Run: bash tests/run.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
scan="$here/../skills/wp-woo-performance-audit/scripts/scan.sh"
tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT
fail=0

cat > "$tmp/bad.php" <<'PHP'
<?php
/**
 * Plugin Name: Bad Shop
 * WC requires at least: 8.2
 */
$args = array( 'posts_per_page' => -1 );
query_posts( 'cat=1' );
session_start();
$orders = get_posts( array( 'post_type' => 'shop_order' ) );
update_post_meta( $order_id, 'x', 'y' );
$rows = $wpdb->get_results( "SELECT * FROM wp_posts WHERE post_type = 'shop_order'" );
error_log( 'card: ' . $_POST['card_number'] );
wp_remote_get( $url );
$data = file_get_contents( 'https://example.com/feed' );
$hits = $wpdb->get_results( "SELECT * FROM t WHERE a LIKE '%term'" );
$ids  = array( 'post__not_in' => $excluded );
$q    = new WP_Query( array( 'post_type' => 'product' ) );
$meta = array( 'key' => 'color', 'compare' => '=' );
$users = get_users();
wp_schedule_event( time(), 'hourly', 'nightly_sync' );
set_transient( "user_{$id}", 1, 60 );
setcookie( 'visitor', 1 );
if ( in_array( $a, $b ) ) {}
$page = url_to_postid( $u );
update_option( 'last_seen', time() );
add_filter( 'wc_session_expiration', function () { return 60 * DAY_IN_SECONDS; } );
wc_enqueue_js( 'console.log(1);' );
wp_enqueue_script( 'wc-cart-fragments' );
$api_key = 'abcdefghijklmnopqrstuvwxyz123456';
public function process_payment( $order_id ) {
    return array( 'result' => 'success' );
}
// webhook handler with no signature check
PHP

cat > "$tmp/bad.js" <<'JS'
import _ from 'lodash';
setInterval( () => fetch( '/wp-json/x' ), 5000 );
$.post( ajaxurl, data );
JS

mkdir -p "$tmp/theme/woocommerce" "$tmp/vendor" "$tmp/admin"
printf '%s\n' '<?php' '<li class="product"><?php the_title(); ?></li>' > "$tmp/theme/woocommerce/content-product.php"
cp "$tmp/bad.php" "$tmp/vendor/lib.php"
cp "$tmp/bad.php" "$tmp/admin/tools.php"

cat > "$tmp/good.php" <<'PHP'
<?php
add_action( 'before_woocommerce_init', function () {
    \Automattic\WooCommerce\Utilities\FeaturesUtil::declare_compatibility( 'custom_order_tables', __FILE__, true );
} );
$orders = wc_get_orders( array( 'limit' => 10 ) );
$r = wp_remote_get( $url, array( 'timeout' => 2 ) );
$m = wp_remote_post(
    $url,
    array( 'timeout' => 3 )
);
if ( in_array( $a, $b, true ) ) {}
if ( ! wp_next_scheduled( 'nightly_sync' ) ) { wp_schedule_event( time(), 'hourly', 'nightly_sync' ); }
$q2 = new WP_Query( array( 'no_found_rows' => true ) );
$meta = array( 'key' => 'is_featured', 'compare' => 'EXISTS' );
$users = get_users( array( 'number' => 100 ) );
if ( is_cart() ) { wp_enqueue_script( 'x', $u, array(), '1.0' ); }
$api_key = get_option( 'api_key' );
function process_payment( $order_id ) {
    if ( ! is_ssl() ) { return array( 'result' => 'failure' ); }
    return array( 'result' => 'success' );
}
PHP

out=$(bash "$scan" "$tmp/bad.php" "$tmp/bad.js" "$tmp/theme/woocommerce/content-product.php")

expect=(query-unbounded query-posts session-start hpos-order-posts hpos-order-meta hpos-wpdb card-data
  remote-no-timeout remote-file-get query-like-lead query-post-not-in query-meta-value product-wp-query
  in-array-loose cron-unguarded cron-long-job transient-dynamic cookie-public uncached-lookup option-write
  wc-session wc-enqueue-js debug-log wc-fragments enqueue-global asset-no-version query-no-found-rows
  payment-ssl hardcoded-key ajax-polling ajax-post-read lodash-full hpos-declaration webhook-unverified
  template-no-hooks)
for id in "${expect[@]}"; do
  printf '%s\n' "$out" | grep -q " $id: " || { echo "FAIL rule did not fire: $id"; fail=1; }
done

clean=$(bash "$scan" "$tmp/good.php")
printf '%s\n' "$clean" | grep -q ': CRITICAL \|: WARNING \|: INFO ' && { echo "FAIL clean file got hits:"; printf '%s\n' "$clean"; fail=1; }

folder=$(bash "$scan" "$tmp")
printf '%s\n' "$folder" | grep -q 'admin/tools.php.*lower risk' || { echo "FAIL admin path not marked lower risk"; fail=1; }
printf '%s\n' "$folder" | grep -q 'vendor/' && { echo "FAIL folder scan read vendor/"; fail=1; }

bash "$scan" > /dev/null 2>&1; [ $? -eq 2 ] || { echo "FAIL no arguments should exit 2"; fail=1; }

[ $fail = 0 ] && echo "scan tests ok (${#expect[@]} rules)" || { echo "scan tests FAILED"; exit 1; }

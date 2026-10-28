# WooCommerce patterns (performance, HPOS, cart and payment safety)

Targets WooCommerce 8.2 through 10.x. HPOS (High-Performance Order Storage) is the default for new stores from 8.2. Code that reads orders as posts breaks there.

## Version notes

| Feature | Version |
|---|---|
| CRUD objects (`wc_get_order`, `WC_Product_Query`) | 3.0+ |
| Additional Checkout Fields API | 8.6+ |
| HPOS default for new stores; `declare_compatibility` expected | 8.2+ |
| Cart fragments no longer global by default | 7.8+ |
| Session cap of 30 days | 10.1+ |
| `wc_enqueue_js()` deprecated, use `wp_add_inline_script()` | 10.4+ |
| Product object caching (opt-in), variation price caching | 10.5+ |

Check the WooCommerce changelog for the store's version before you call a pattern wrong. Cite the URL.

## HPOS (CRITICAL)

**Declaration.** The main plugin file must declare compatibility:

```php
add_action( 'before_woocommerce_init', function () {
    if ( class_exists( \Automattic\WooCommerce\Utilities\FeaturesUtil::class ) ) {
        \Automattic\WooCommerce\Utilities\FeaturesUtil::declare_compatibility( 'custom_order_tables', __FILE__, true );
    }
} );
```

The scan reports `hpos-declaration` when no file declares it. On a partial scan, check the rest of the plugin before you call it missing.

**Order access.** Use CRUD, never post functions:

| Rule | Severity | Bad | Good |
|---|---|---|---|
| `hpos-order-posts` | CRITICAL | `get_posts()` or `WP_Query` with `shop_order` | `wc_get_orders( array( 'status' => 'completed', 'limit' => 10 ) )` |
| `hpos-order-meta` | CRITICAL | `update_post_meta( $order_id, ... )` | `$order = wc_get_order( $id ); $order->update_meta_data( ... ); $order->save();` |
| `hpos-wpdb` | CRITICAL | `$wpdb` on `wp_posts` or `wp_postmeta` for orders | CRUD APIs, or the store's order tables through `wc_get_orders` |

Custom post types that are not orders may use `get_posts()` and `WP_Query`. Flag only the order and product cases.

## Products (WARNING)

- `WP_Query` with `post_type => product` (rule `product-wp-query`): use `wc_get_products()` or `WC_Product_Query`.
- Repeated `wc_get_product()` for the same ID in a loop: load once, or cache per request.

## Cart fragments (WARNING, usually the biggest front-end cost)

`wc-cart-fragments` runs on every page if nothing dequeues it. Keep it on cart, checkout and product pages only. On current stores, consider the Mini-Cart block, which avoids fragments.

```php
add_action( 'wp_enqueue_scripts', function () {
    if ( ! is_woocommerce() && ! is_cart() && ! is_checkout() ) {
        wp_dequeue_script( 'wc-cart-fragments' );
    }
}, 100 );
```

Check the result in the browser: no `wc-cart-fragments` request on the blog or home page.

## Action Scheduler (WARNING for bulk work on wp-cron)

Action Scheduler ships with WooCommerce. Use it for bulk or retryable store work.

```php
as_enqueue_async_action( 'prefix_export_batch', array( 'batch' => 0 ), 'prefix-exports' );

add_action( 'prefix_export_batch', function ( $batch ) {
    $orders = wc_get_orders( array( 'limit' => 100, 'offset' => $batch * 100 ) );
    // ... work on $orders
    if ( 100 === count( $orders ) ) {
        as_enqueue_async_action( 'prefix_export_batch', array( 'batch' => $batch + 1 ), 'prefix-exports' );
    }
} );
```

Rule `cron-unguarded` flags `wp_schedule_event` calls with no `wp_next_scheduled()` guard. Bulk WooCommerce work belongs on Action Scheduler.

## Sessions (WARNING)

- From WC 10.1 the session lifetime is capped at 30 days. A `wc_session_expiration` filter that asks for more is a bug to check (rule `wc-session`, INFO).
- Custom session storage that bypasses `WC_Session_Handler` breaks cart state under caching.

## Checkout and cart hooks

Use hooks, not copies of core code:

| Need | Hook |
|---|---|
| Validate on submit | `woocommerce_checkout_process` |
| Save custom order data | `woocommerce_checkout_create_order` (receives `$order` before WooCommerce saves it) |
| Custom cart item data | `woocommerce_add_cart_item_data` |
| Fees | `woocommerce_cart_calculate_fees` |
| Cart validation | `woocommerce_check_cart_items` |
| Status change | `woocommerce_order_status_changed` |
| Change status | `$order->set_status( 'processing', 'note' )` then `$order->save()`, not `wp_update_post` |

Older code often uses `woocommerce_checkout_update_order_meta`. New code should use `woocommerce_checkout_create_order`.

Sanitize `$_POST` values when you copy them (`sanitize_text_field`, `sanitize_textarea_field`). Run `lean-project audit security` on the file.

## Template overrides (CRITICAL when hooks are deleted)

Override only when no hook fits. Keep every `do_action()` and `apply_filters()` of the original template.

- rule `template-no-hooks`: a file under `woocommerce/` with no `do_action` or `apply_filters`. Compare it with the core template for the version the store runs.
- Keep the `@version` line in step with the core template. A stale version is a WARNING (it may miss core fixes).
- Prefer a hook (for example `woocommerce_shop_loop_item_title` at a new priority) to a copy of the whole template.

## Payments and webhooks (code-level safety only)

This is not a PCI audit.

| Rule | Severity | Check |
|---|---|---|
| `card-data` | CRITICAL | Raw card number or CVV stored in meta, options, tables, sessions or logs |
| `payment-ssl` | WARNING | `process_payment()` without an HTTPS check outside test mode |
| `hardcoded-key` | WARNING | API keys in code (use settings) |
| `webhook-unverified` | CRITICAL | Webhook handler with no signature check (`hash_equals()` with HMAC) |

- Return `array( 'result' => 'success', 'redirect' => ... )` from `process_payment()`.
- Use `$order->payment_complete( $transaction_id )` for payment, not a manual status change.
- Check webhook duplicates by delivery ID, and process the work through Action Scheduler.

## Shipping and product types (code-level)

- Shipping methods: `calculate_shipping()` should only add rates. Expensive remote rate lookups belong in a cache with a short TTL.
- Custom product types: register the type, the class and the data store. Check that `get_type()` matches the registered type.

## Triage a slow store

1. Measure the cart and checkout pages (Query Monitor on staging). Note query count and time.
2. Check cache bypass on the cart and checkout (cookies, sessions). Cart and checkout are never cached, so keep the rest of the site cacheable.
3. Find product queries through `WP_Query`, order queries through posts, and fragments on every page.
4. Check remote calls on the cart path (shipping quotes, tax APIs, payment checks) for timeouts and caching.
5. Check Action Scheduler backlog (WooCommerce, Scheduled Actions screen) for stalled jobs that load the server.

## Report

Group findings by file. Each finding: the rule ID, line, the problem, the fix. Show a BAD/GOOD pair for HPOS and template findings, where the fix is not obvious.

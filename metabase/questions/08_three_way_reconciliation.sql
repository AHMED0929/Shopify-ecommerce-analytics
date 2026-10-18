-- ============================================================================
-- 08 · Three-Way Reconciliation — claimed vs last-click vs accounting
-- Dashboard: Full-Funnel Executive + Reconciliation & Audit Appendix
-- Verified: 3,613 / $2,067,213.14 / 1.39 · 3,245 / $1,636,464.21 / 1.10
--           11,718 / $6,181,499.29 / 4.15 (net MER)
-- All three ratios share the same denominator: $1,488,730.67 ad spend.
-- ============================================================================

WITH r AS (
  SELECT * FROM `ecommerce-bi-analytics.full_funnel.vw_reconciliation_summary`
)
SELECT sort_order, source, purchases, revenue, ratio_vs_spend, note
FROM (
  SELECT 1 AS sort_order, 'Meta claimed' AS source,
    r.meta_claimed_purchases AS purchases,
    r.meta_claimed_revenue AS revenue,
    ROUND(r.platform_claimed_roas, 2) AS ratio_vs_spend,
    'Platform-reported · includes +25% modeled view-through / multi-touch inflation' AS note
  FROM r
  UNION ALL
  SELECT 2, 'GA4 paid last-click',
    r.paid_ga4_purchases,
    r.paid_ga4_net_revenue,
    ROUND(r.paid_last_click_roas, 2),
    'Paid-attributed orders, last-click attribution'
  FROM r
  UNION ALL
  SELECT 3, 'Shopify (accounting truth)',
    r.shopify_valid_orders,
    r.shopify_net_revenue,
    ROUND(r.net_mer, 2),
    'All traffic · ratio vs spend = Net MER (store economics, not platform attribution)'
  FROM r
)
ORDER BY sort_order;

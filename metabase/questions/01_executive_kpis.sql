-- ============================================================================
-- 01 · Executive KPIs — one row per KPI (pin as a table on the Executive page)
-- Dashboard: Full-Funnel Executive
-- Verified against the Power BI flagship (2026-10-17):
--   GMV $6,252,668.43 · Net $6,181,499.29 · 11,718 orders · 4,972 customers
-- ============================================================================

WITH r AS (
  SELECT * FROM `ecommerce-bi-analytics.full_funnel.vw_reconciliation_summary`
),
cust AS (
  SELECT
    COUNT(*) AS customers,
    COUNTIF(lifetime_orders >= 2) AS repeat_customers,
    ROUND(
      SAFE_DIVIDE(SUM(IF(lifetime_orders >= 2, lifetime_net_revenue, 0)), SUM(lifetime_net_revenue)) * 100,
      1
    ) AS repeat_revenue_share_pct
  FROM `ecommerce-bi-analytics.full_funnel.vw_customers`
),
funnel AS (
  SELECT
    SUM(sessions) AS total_sessions,
    ROUND(SAFE_DIVIDE(SUM(purchase_sessions), SUM(begin_checkout_sessions)) * 100, 1) AS checkout_completion_pct
  FROM `ecommerce-bi-analytics.full_funnel.vw_daily_full_funnel`
),
ltv AS (
  -- 12-month LTV per customer, mature cohorts only (acquired <= Aug 2025)
  SELECT ROUND(SAFE_DIVIDE(SUM(o.net_revenue), COUNT(DISTINCT v.customer_email)), 2) AS ltv_12m
  FROM `ecommerce-bi-analytics.full_funnel.vw_orders_enriched` o
  JOIN `ecommerce-bi-analytics.full_funnel.vw_customers` v USING (customer_email)
  WHERE o.is_valid_revenue_order = 1
    AND v.cohort_month <= DATE '2025-08-01'
    AND o.cohort_month_index BETWEEN 0 AND 12
)
SELECT sort_order, metric, value, context
FROM (
  SELECT 1 AS sort_order, 'GMV' AS metric,
    CONCAT('$', FORMAT("%'.2f", r.shopify_gross_gmv)) AS value,
    'Valid orders (paid + partially_refunded), Sep 2024 – Aug 2026' AS context
  FROM r
  UNION ALL
  SELECT 2, 'Net Revenue', CONCAT('$', FORMAT("%'.2f", r.shopify_net_revenue)),
    'GMV − refunds ($71,169.14, 1.14%)' FROM r
  UNION ALL
  SELECT 3, 'Valid Orders', FORMAT("%'d", r.shopify_valid_orders),
    '12,000 raw − 282 excluded (refunded / pending / voided)' FROM r
  UNION ALL
  SELECT 4, 'Average Order Value', CONCAT('$', FORMAT("%'.2f", SAFE_DIVIDE(r.shopify_gross_gmv, r.shopify_valid_orders))),
    'GMV ÷ valid orders' FROM r
  UNION ALL
  SELECT 5, 'Customers', FORMAT("%'d", c.customers),
    'Distinct customers on valid orders' FROM cust c
  UNION ALL
  SELECT 6, 'Repeat Purchase Rate', CONCAT(CAST(ROUND(SAFE_DIVIDE(c.repeat_customers, c.customers) * 100, 1) AS STRING), '%'),
    CONCAT(FORMAT("%'d", c.repeat_customers), ' repeat buyers (2+ valid orders)') FROM cust c
  UNION ALL
  SELECT 7, 'Repeat Revenue Share', CONCAT(CAST(c.repeat_revenue_share_pct AS STRING), '%'),
    'Net Revenue from repeat buyers' FROM cust c
  UNION ALL
  SELECT 8, '12-Month LTV per Customer', CONCAT('$', FORMAT("%'.2f", l.ltv_12m)),
    'Mature cohorts (acquired ≤ Aug 2025), months 0–12' FROM ltv l
  UNION ALL
  SELECT 9, 'Total Ad Spend', CONCAT('$', FORMAT("%'.2f", r.total_ad_spend)),
    'Simulated paid media, campaign-day grain' FROM r
  UNION ALL
  SELECT 10, 'Gross MER', CONCAT(FORMAT('%.2f', r.gross_mer), 'x'),
    'GMV ÷ ad spend' FROM r
  UNION ALL
  SELECT 11, 'Net MER', CONCAT(FORMAT('%.2f', r.net_mer), 'x'),
    'Net Revenue ÷ ad spend' FROM r
  UNION ALL
  SELECT 12, 'Blended CPA', CONCAT('$', FORMAT("%'.2f", r.blended_cpa)),
    'Ad spend ÷ all valid orders' FROM r
  UNION ALL
  SELECT 13, 'Blended CAC', CONCAT('$', FORMAT("%'.2f", r.blended_cac)),
    'Ad spend ÷ all customers' FROM r
  UNION ALL
  SELECT 14, 'Paid Last-Click ROAS', CONCAT(FORMAT('%.2f', r.paid_last_click_roas), 'x'),
    'Paid-attributed Net Revenue ÷ ad spend' FROM r
  UNION ALL
  SELECT 15, 'Meta-Claimed ROAS', CONCAT(FORMAT('%.2f', r.platform_claimed_roas), 'x'),
    'Platform-reported (incl. +25% modeled inflation) ÷ ad spend' FROM r
  UNION ALL
  SELECT 16, 'Checkout Completion (session grain)', CONCAT(CAST(f.checkout_completion_pct AS STRING), '%'),
    'Purchase sessions ÷ begin-checkout sessions' FROM funnel f
  UNION ALL
  SELECT 17, 'Total Sessions', FORMAT("%'d", f.total_sessions),
    'GA4 sessions, 24 months' FROM funnel f
)
ORDER BY sort_order;

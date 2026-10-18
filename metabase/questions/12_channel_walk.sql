-- ============================================================================
-- 12 · Channel Walk — Internal / Organic / Paid (audit table 2)
-- Dashboard: Reconciliation & Audit Appendix
-- Verified: Internal 441 / $232,459.32 · Organic 8,032 / $4,312,575.76
--           Paid 3,245 / $1,636,464.21 on $1,488,730.67 spend (last-click 1.10)
-- Organic + Internal together = 73.5% of store Net Revenue.
-- Total row: 11,718 orders / $6,252,668.43 GMV / $6,181,499.29 net / 4.15x.
-- ============================================================================

WITH orders AS (
  SELECT
    traffic_type,
    COUNTIF(is_valid_revenue_order = 1)                               AS valid_orders,
    ROUND(SUM(IF(is_valid_revenue_order = 1, gross_revenue, 0)), 2)   AS gmv,
    ROUND(SUM(IF(is_valid_revenue_order = 1, refunded_amount, 0)), 2) AS refunds,
    ROUND(SUM(IF(is_valid_revenue_order = 1, net_revenue, 0)), 2)     AS net_revenue
  FROM `ecommerce-bi-analytics.full_funnel.vw_orders_enriched`
  GROUP BY traffic_type
),
spend AS (
  SELECT
    traffic_type,
    ROUND(SUM(ad_spend), 2) AS ad_spend
  FROM `ecommerce-bi-analytics.full_funnel.vw_daily_full_funnel`
  GROUP BY traffic_type
),
chan AS (
  SELECT
    o.traffic_type,
    o.valid_orders,
    o.gmv,
    o.refunds,
    o.net_revenue,
    COALESCE(s.ad_spend, 0) AS ad_spend,
    ROUND(SAFE_DIVIDE(o.net_revenue, s.ad_spend), 2) AS net_mer
  FROM orders o
  LEFT JOIN spend s USING (traffic_type)
)
SELECT * FROM chan
UNION ALL
SELECT
  'Total',
  SUM(valid_orders),
  ROUND(SUM(gmv), 2),
  ROUND(SUM(refunds), 2),
  ROUND(SUM(net_revenue), 2),
  ROUND(SUM(ad_spend), 2),
  ROUND(SAFE_DIVIDE(SUM(net_revenue), SUM(ad_spend)), 2)
FROM chan
ORDER BY CASE WHEN traffic_type = 'Total' THEN 1 ELSE 0 END, net_revenue DESC;

-- ============================================================================
-- DS7 · Campaign unit economics — Looker Studio custom query
-- Sources: `ecommerce-bi-analytics.full_funnel.vw_orders_enriched`
--          `ecommerce-bi-analytics.full_funnel.vw_daily_full_funnel`
-- Feeds  : Campaign Unit Economics table (10 campaign rows)
-- Looker renames: channel -> Channel · campaign -> Campaign · orders -> Orders ·
--                 gmv -> GMV · refunds -> Refunds · net_revenue -> Net revenue ·
--                 ad_spend -> Ad spend · net_mer -> Net MER · cpa -> CPA
-- Verified: 10 rows · Paid 3,245 orders / $1,636,464.21 net / $1,488,730.67 spend ·
--           Organic 8,032 / $4,312,575.76 · Internal 441 / $232,459.32
-- No trailing semicolon: Looker Studio rejects it.
-- ============================================================================

WITH orders AS (
  SELECT
    traffic_type,
    campaign_name,
    COUNTIF(is_valid_revenue_order = 1)                               AS valid_orders,
    ROUND(SUM(IF(is_valid_revenue_order = 1, gross_revenue, 0)), 2)   AS gmv,
    ROUND(SUM(IF(is_valid_revenue_order = 1, refunded_amount, 0)), 2) AS refunds,
    ROUND(SUM(IF(is_valid_revenue_order = 1, net_revenue, 0)), 2)     AS net_revenue
  FROM `ecommerce-bi-analytics.full_funnel.vw_orders_enriched`
  GROUP BY traffic_type, campaign_name
),
spend AS (
  SELECT
    traffic_type,
    campaign_name,
    ROUND(SUM(ad_spend), 2) AS ad_spend
  FROM `ecommerce-bi-analytics.full_funnel.vw_daily_full_funnel`
  GROUP BY traffic_type, campaign_name
)
SELECT
  o.traffic_type     AS channel,
  o.campaign_name    AS campaign,
  o.valid_orders     AS orders,
  o.gmv              AS gmv,
  o.refunds          AS refunds,
  o.net_revenue      AS net_revenue,
  COALESCE(s.ad_spend, 0) AS ad_spend,
  ROUND(SAFE_DIVIDE(o.net_revenue, s.ad_spend), 2) AS net_mer,
  ROUND(SAFE_DIVIDE(s.ad_spend, o.valid_orders), 2) AS cpa
FROM orders o
LEFT JOIN spend s USING (traffic_type, campaign_name)
ORDER BY o.net_revenue DESC

-- ============================================================================
-- Full-Funnel Commerce Intelligence — BigQuery view definitions
-- ----------------------------------------------------------------------------
-- Dataset: `ecommerce-bi-analytics.full_funnel`
--
-- Prerequisites
--   1. Create the dataset `full_funnel` in your BigQuery project.
--   2. Upload the six CSVs produced by `generate_funnel.py` as tables
--      (Create table > Upload, schema: auto detect):
--        dim_campaign, bridge_order_campaign, fact_orders, fact_order_items,
--        fact_ga4_funnel, fact_adspend
--   3. Run this script top to bottom.
--
-- Forking under another project? Search-replace `ecommerce-bi-analytics`
-- with your own project ID.
--
-- Contract (matches the packaged Power BI report):
--   vw_orders_enriched        one row per order (12,000); valid = paid +
--                             partially_refunded (11,718)
--   vw_daily_full_funnel      date x campaign spine via UNION DISTINCT of the
--                             GA4-funnel and ad-spend keys (3,959 rows)
--   vw_reconciliation_summary single row; paid + blended CPA/CAC
--   vw_customers              one row per customer (4,972) — the grain
--                             contract behind every cohort denominator
--
-- Expected totals after creation (cross-check in the console):
--   vw_orders_enriched:        11,718 valid | GMV 6,252,668.43 | Net 6,181,499.29
--   vw_daily_full_funnel:      spend 1,488,730.67 | sessions 1,327,199 | purchases 11,718
--   vw_reconciliation_summary: Gross MER 4.20 | Net MER 4.15 | Paid CPA 458.78 | Paid CAC 670.60
--   vw_customers:              4,972 rows | tiers 1,516 / 1,544 / 1,912
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1) vw_orders_enriched — order grain + customer cohort fields
--    Adds is_valid_revenue_order, cohort_month (month of the customer's first
--    valid order), valid_order_seq (1,2,3... among valid orders) and
--    cohort_month_index (months between the order and its cohort month).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `ecommerce-bi-analytics.full_funnel.vw_orders_enriched` AS
WITH base AS (
  SELECT
    f.order_name,
    f.order_date,
    f.order_timestamp,
    f.email                     AS customer_email,
    f.financial_status,
    f.source                    AS platform_source,
    b.campaign_id,
    d.campaign_name,
    d.platform                  AS marketing_platform,
    d.traffic_type,
    b.utm_source,
    b.utm_medium,
    f.total                     AS gross_revenue,
    f.refunded_amount,
    f.net_revenue,
    IF(f.financial_status IN ('paid', 'partially_refunded'), 1, 0) AS is_valid_revenue_order
  FROM `ecommerce-bi-analytics.full_funnel.fact_orders` f
  LEFT JOIN `ecommerce-bi-analytics.full_funnel.bridge_order_campaign` b
    ON b.order_name = f.order_name
  LEFT JOIN `ecommerce-bi-analytics.full_funnel.dim_campaign` d
    ON d.campaign_id = b.campaign_id
),
cohorts AS (
  SELECT
    customer_email,
    DATE_TRUNC(MIN(order_date), MONTH) AS cohort_month
  FROM base
  WHERE is_valid_revenue_order = 1
  GROUP BY customer_email
),
sequenced AS (
  SELECT
    order_name,
    ROW_NUMBER() OVER (
      PARTITION BY customer_email
      ORDER BY order_date, order_timestamp, order_name
    ) AS valid_order_seq
  FROM base
  WHERE is_valid_revenue_order = 1
)
SELECT
  b.order_name,
  b.order_date,
  b.order_timestamp,
  b.customer_email,
  b.financial_status,
  b.platform_source,
  b.campaign_id,
  b.campaign_name,
  b.marketing_platform,
  b.traffic_type,
  b.utm_source,
  b.utm_medium,
  b.gross_revenue,
  b.refunded_amount,
  b.net_revenue,
  b.is_valid_revenue_order,
  c.cohort_month,
  s.valid_order_seq,
  DATE_DIFF(DATE_TRUNC(b.order_date, MONTH), c.cohort_month, MONTH) AS cohort_month_index
FROM base b
LEFT JOIN cohorts c USING (customer_email)
LEFT JOIN sequenced s USING (order_name);


-- ----------------------------------------------------------------------------
-- 2) vw_daily_full_funnel — GA4 funnel + ad delivery at date x campaign grain
--    The key spine is the UNION DISTINCT of both fact tables' keys, so every
--    date x campaign row carries whichever side exists (spend or sessions).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `ecommerce-bi-analytics.full_funnel.vw_daily_full_funnel` AS
WITH spine AS (
  SELECT date, campaign_id FROM `ecommerce-bi-analytics.full_funnel.fact_ga4_funnel`
  UNION DISTINCT
  SELECT date, campaign_id FROM `ecommerce-bi-analytics.full_funnel.fact_adspend`
)
SELECT
  s.date,
  s.campaign_id,
  d.campaign_name,
  d.platform,
  d.traffic_type,
  d.default_utm_medium,
  COALESCE(a.spend, 0)                       AS ad_spend,
  COALESCE(a.impressions, 0)                 AS impressions,
  COALESCE(a.clicks, 0)                      AS link_clicks,
  COALESCE(a.platform_claimed_purchases, 0)  AS platform_claimed_purchases,
  COALESCE(a.platform_claimed_revenue, 0)    AS platform_claimed_revenue,
  COALESCE(f.sessions, 0)                    AS sessions,
  COALESCE(f.view_item_sessions, 0)          AS view_item_sessions,
  COALESCE(f.add_to_cart_sessions, 0)        AS add_to_cart_sessions,
  COALESCE(f.begin_checkout_sessions, 0)     AS begin_checkout_sessions,
  COALESCE(f.purchase_sessions, 0)           AS purchase_sessions,
  COALESCE(f.purchases, 0)                   AS ga4_purchases,
  COALESCE(f.revenue, 0)                     AS ga4_gross_revenue,
  COALESCE(f.refunds, 0)                     AS refunds,
  COALESCE(f.net_revenue, 0)                 AS ga4_net_revenue,
  SAFE_DIVIDE(a.spend, a.impressions) * 1000 AS cpm,
  SAFE_DIVIDE(a.clicks, a.impressions)       AS ctr,
  SAFE_DIVIDE(a.spend, a.clicks)             AS cpc
FROM spine s
LEFT JOIN `ecommerce-bi-analytics.full_funnel.fact_ga4_funnel` f
  ON f.date = s.date AND f.campaign_id = s.campaign_id
LEFT JOIN `ecommerce-bi-analytics.full_funnel.fact_adspend` a
  ON a.date = s.date AND a.campaign_id = s.campaign_id
LEFT JOIN `ecommerce-bi-analytics.full_funnel.dim_campaign` d
  ON d.campaign_id = s.campaign_id;


-- ----------------------------------------------------------------------------
-- 3) vw_reconciliation_summary — single row; the 3-way truth table
--    Meta-claimed vs GA4 paid last-click vs Shopify accounting.
--    Paid cuts filter `dim_campaign.traffic_type = 'Paid'`.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `ecommerce-bi-analytics.full_funnel.vw_reconciliation_summary` AS
WITH spend AS (
  SELECT
    SUM(spend)                      AS total_ad_spend,
    SUM(platform_claimed_purchases) AS meta_claimed_purchases,
    SUM(platform_claimed_revenue)   AS meta_claimed_revenue
  FROM `ecommerce-bi-analytics.full_funnel.fact_adspend`
),
paid_funnel AS (
  SELECT
    SUM(f.purchases)                AS paid_ga4_purchases,
    ROUND(SUM(f.net_revenue), 2)    AS paid_ga4_net_revenue
  FROM `ecommerce-bi-analytics.full_funnel.fact_ga4_funnel` f
  JOIN `ecommerce-bi-analytics.full_funnel.dim_campaign` d
    ON d.campaign_id = f.campaign_id
  WHERE d.traffic_type = 'Paid'
),
order_rollup AS (
  SELECT
    COUNTIF(is_valid_revenue_order = 1)                               AS shopify_valid_orders,
    COUNT(DISTINCT IF(is_valid_revenue_order = 1, customer_email, NULL)) AS shopify_valid_customers,
    ROUND(SUM(IF(is_valid_revenue_order = 1, gross_revenue, 0)), 2)  AS shopify_gross_gmv,
    ROUND(SUM(IF(is_valid_revenue_order = 1, net_revenue, 0)), 2)    AS shopify_net_revenue,
    COUNT(DISTINCT IF(is_valid_revenue_order = 1 AND traffic_type = 'Paid', customer_email, NULL)) AS paid_valid_customers
  FROM `ecommerce-bi-analytics.full_funnel.vw_orders_enriched`
)
SELECT
  sp.total_ad_spend,
  sp.meta_claimed_purchases,
  sp.meta_claimed_revenue,
  SAFE_DIVIDE(sp.meta_claimed_revenue, sp.total_ad_spend) AS platform_claimed_roas,
  pf.paid_ga4_purchases,
  orl.paid_valid_customers,
  pf.paid_ga4_net_revenue,
  SAFE_DIVIDE(pf.paid_ga4_net_revenue, sp.total_ad_spend) AS paid_last_click_roas,
  SAFE_DIVIDE(sp.total_ad_spend, pf.paid_ga4_purchases)   AS paid_cpa,
  SAFE_DIVIDE(sp.total_ad_spend, orl.paid_valid_customers) AS paid_cac,
  orl.shopify_valid_orders,
  orl.shopify_valid_customers,
  orl.shopify_gross_gmv,
  orl.shopify_net_revenue,
  SAFE_DIVIDE(orl.shopify_gross_gmv, sp.total_ad_spend)   AS gross_mer,
  SAFE_DIVIDE(orl.shopify_net_revenue, sp.total_ad_spend) AS net_mer,
  SAFE_DIVIDE(sp.total_ad_spend, orl.shopify_valid_orders)     AS blended_cpa,
  SAFE_DIVIDE(sp.total_ad_spend, orl.shopify_valid_customers)  AS blended_cac
FROM spend sp
CROSS JOIN paid_funnel pf
CROSS JOIN order_rollup orl;


-- ----------------------------------------------------------------------------
-- 4) vw_customers — one row per customer (4,972); the cohort denominator table
--    tier values: '1 Order (One-Time)' / '2 Orders' / '3+ Orders'
--    first_sku   : alphabetical MIN of SKUs on the first valid order (caveat:
--                  multi-item first orders collapse to the min SKU)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `ecommerce-bi-analytics.full_funnel.vw_customers` AS
WITH valid_orders AS (
  SELECT
    o.*,
    ROW_NUMBER() OVER (
      PARTITION BY o.customer_email
      ORDER BY o.order_date, o.order_timestamp, o.order_name
    ) AS rn
  FROM `ecommerce-bi-analytics.full_funnel.vw_orders_enriched` o
  WHERE o.is_valid_revenue_order = 1
),
first_orders AS (
  SELECT customer_email, order_name
  FROM valid_orders
  WHERE rn = 1
),
first_skus AS (
  SELECT
    fo.customer_email,
    MIN(i.lineitem_sku) AS first_sku
  FROM first_orders fo
  JOIN `ecommerce-bi-analytics.full_funnel.fact_order_items` i
    ON i.order_name = fo.order_name
  GROUP BY fo.customer_email
)
SELECT
  v.customer_email,
  MIN(v.order_date)                        AS first_order_date,
  DATE_TRUNC(MIN(v.order_date), MONTH)     AS cohort_month,
  COUNT(DISTINCT v.order_name)             AS lifetime_orders,
  ROUND(SUM(v.net_revenue), 2)             AS lifetime_net_revenue,
  CASE
    WHEN COUNT(DISTINCT v.order_name) = 1 THEN '1 Order (One-Time)'
    WHEN COUNT(DISTINCT v.order_name) = 2 THEN '2 Orders'
    ELSE '3+ Orders'
  END                                      AS customer_order_tier,
  MAX(IF(v.rn = 1, v.traffic_type, NULL))  AS first_order_traffic_type,
  MAX(fs.first_sku)                        AS first_sku
FROM valid_orders v
LEFT JOIN first_skus fs
  ON fs.customer_email = v.customer_email
GROUP BY v.customer_email;


-- ----------------------------------------------------------------------------
-- Optional verification queries (run individually after the views exist):
--   SELECT COUNT(*) FROM `ecommerce-bi-analytics.full_funnel.vw_orders_enriched`;
--     -- 12,000
--   SELECT COUNTIF(is_valid_revenue_order = 1) AS valid_orders
--   FROM `ecommerce-bi-analytics.full_funnel.vw_orders_enriched`;
--     -- 11,718
--   SELECT COUNT(*) FROM `ecommerce-bi-analytics.full_funnel.vw_daily_full_funnel`;
--     -- 3,959
--   SELECT shopify_gross_gmv, shopify_net_revenue, gross_mer, net_mer, paid_cpa, paid_cac
--   FROM `ecommerce-bi-analytics.full_funnel.vw_reconciliation_summary`;
--     -- 6,252,668.43 | 6,181,499.29 | 4.20 | 4.15 | 458.78 | 670.60
--   SELECT COUNT(*), COUNTIF(customer_order_tier = '1 Order (One-Time)') AS tier1,
--          COUNTIF(customer_order_tier = '2 Orders') AS tier2,
--          COUNTIF(customer_order_tier = '3+ Orders') AS tier3
--   FROM `ecommerce-bi-analytics.full_funnel.vw_customers`;
--     -- 4,972 | 1,516 | 1,544 | 1,912
-- ----------------------------------------------------------------------------

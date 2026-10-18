-- ============================================================================
-- 09 · Order-Status Gross-to-Net Walk (audit table 1)
-- Dashboard: Reconciliation & Audit Appendix
-- Verified: 12,000 raw -> 282 excluded -> 11,718 valid
--   gross $6,252,668.43 -> refunds $71,169.14 -> net $6,181,499.29
-- Total row: 12,000 / 11,718 / $6,385,333.39 gross / $146,198.45 refunds /
--   $6,181,499.29 valid net
-- ============================================================================

WITH base AS (
  SELECT
    financial_status,
    COUNT(*)                                                  AS raw_orders,
    COUNTIF(is_valid_revenue_order = 1)                       AS valid_orders,
    ROUND(SUM(gross_revenue), 2)                              AS gross_revenue,
    ROUND(SUM(refunded_amount), 2)                            AS refunds,
    ROUND(SUM(IF(is_valid_revenue_order = 1, net_revenue, 0)), 2) AS valid_net_revenue
  FROM `ecommerce-bi-analytics.full_funnel.vw_orders_enriched`
  GROUP BY financial_status
),
total AS (
  SELECT
    'Total'                                                   AS financial_status,
    COUNT(*)                                                  AS raw_orders,
    COUNTIF(is_valid_revenue_order = 1)                       AS valid_orders,
    ROUND(SUM(gross_revenue), 2)                              AS gross_revenue,
    ROUND(SUM(refunded_amount), 2)                            AS refunds,
    ROUND(SUM(IF(is_valid_revenue_order = 1, net_revenue, 0)), 2) AS valid_net_revenue
  FROM `ecommerce-bi-analytics.full_funnel.vw_orders_enriched`
)
SELECT * FROM base
UNION ALL
SELECT * FROM total
ORDER BY CASE financial_status
  WHEN 'paid' THEN 1
  WHEN 'partially_refunded' THEN 2
  WHEN 'pending' THEN 3
  WHEN 'refunded' THEN 4
  WHEN 'voided' THEN 5
  WHEN 'Total' THEN 6
  ELSE 7
END;

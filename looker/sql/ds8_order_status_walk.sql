-- ============================================================================
-- DS8 · Order-status gross-to-net walk — Looker Studio custom query
-- Source: `ecommerce-bi-analytics.full_funnel.vw_orders_enriched`
-- Feeds : Order-Status Gross-to-Net Walk (5 status rows + native Grand total)
-- Looker renames: status -> Status · raw_orders -> Raw orders ·
--                 valid_orders -> Valid orders · gross_revenue -> Gross revenue ·
--                 refunds -> Refunds · valid_net_revenue -> Valid net revenue
-- Notes : The report renders the total with Looker's native summary row
--         (`Grand total`), not a SQL UNION, because Looker ignores a custom
--         query's ORDER BY and cannot pin a SQL total row to the bottom.
--         Grand-total expected: 12,000 raw / 11,718 valid / $6,385,333.39 gross /
--         $146,198.45 refunds / $6,181,499.29 valid net.
-- No trailing semicolon: Looker Studio rejects it.
-- ============================================================================

WITH walk AS (
  SELECT
    financial_status,
    COUNT(*)                                                      AS raw_orders,
    COUNTIF(is_valid_revenue_order = 1)                           AS valid_orders,
    ROUND(SUM(gross_revenue), 2)                                  AS gross_revenue,
    ROUND(SUM(refunded_amount), 2)                                AS refunds,
    ROUND(SUM(IF(is_valid_revenue_order = 1, net_revenue, 0)), 2) AS valid_net_revenue
  FROM `ecommerce-bi-analytics.full_funnel.vw_orders_enriched`
  GROUP BY financial_status
)
SELECT
  financial_status AS status,
  raw_orders,
  valid_orders,
  gross_revenue,
  refunds,
  valid_net_revenue
FROM walk
ORDER BY CASE financial_status
  WHEN 'paid' THEN 1
  WHEN 'partially_refunded' THEN 2
  WHEN 'pending' THEN 3
  WHEN 'refunded' THEN 4
  WHEN 'voided' THEN 5
  ELSE 6
END

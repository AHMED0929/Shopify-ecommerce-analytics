-- ============================================================================
-- KPI · 12-Month LTV — scalar tile for the executive KPI strip ($1,120; exact $1,120.08 in 01)
-- Dashboard: Full-Funnel Executive (6-tile strip above the KPI table)
-- ============================================================================
SELECT CONCAT('$', FORMAT("%'.0f", SAFE_DIVIDE(SUM(o.net_revenue), COUNT(DISTINCT v.customer_email)))) AS ltv_12m
FROM `ecommerce-bi-analytics.full_funnel.vw_orders_enriched` o
JOIN `ecommerce-bi-analytics.full_funnel.vw_customers` v USING (customer_email)
WHERE o.is_valid_revenue_order = 1
  AND v.cohort_month <= DATE '2025-08-01'
  AND o.cohort_month_index BETWEEN 0 AND 12;

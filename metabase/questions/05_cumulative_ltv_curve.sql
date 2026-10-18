-- ============================================================================
-- 05 · Cumulative LTV Curve — mature cohorts, months 0–12
-- Dashboard: Retention & Cohort LTV (line chart)
-- Verified: ends at $1,120.08 per customer across 3,638 mature customers
-- Mature = acquired <= Aug 2025, so every cohort has a full 12-month window.
-- ============================================================================

WITH mature AS (
  SELECT customer_email
  FROM `ecommerce-bi-analytics.full_funnel.vw_customers`
  WHERE cohort_month <= DATE '2025-08-01'
),
monthly AS (
  SELECT
    o.cohort_month_index,
    SUM(o.net_revenue) AS net_revenue
  FROM `ecommerce-bi-analytics.full_funnel.vw_orders_enriched` o
  JOIN mature m USING (customer_email)
  WHERE o.is_valid_revenue_order = 1
    AND o.cohort_month_index BETWEEN 0 AND 12
  GROUP BY o.cohort_month_index
)
SELECT
  cohort_month_index,
  ROUND(net_revenue, 2) AS month_net_revenue,
  ROUND(
    SUM(net_revenue) OVER (ORDER BY cohort_month_index) / (SELECT COUNT(*) FROM mature),
    2
  ) AS cumulative_ltv_per_customer
FROM monthly
ORDER BY cohort_month_index;

-- ============================================================================
-- 11 · Cohort Sizes — new customers per acquisition month
-- Dashboard: Retention & Cohort LTV (bar chart, pairs with the LTV curve)
-- Verified: 24 cohorts summing to 4,972 customers.
-- cohort stays DATE-typed: string cohorts suppress the bar chart's x-axis tick labels (v0.64).
-- ============================================================================

SELECT
  cohort_month AS cohort,
  COUNT(*) AS new_customers
FROM `ecommerce-bi-analytics.full_funnel.vw_customers`
GROUP BY cohort_month
ORDER BY cohort_month;

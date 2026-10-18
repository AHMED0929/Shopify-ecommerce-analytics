-- ============================================================================
-- 04 · Cohort Retention Matrix — monthly cohorts x months 0–12 (wide heatmap table)
-- Dashboard: Retention & Cohort LTV (matrix: 24 cohort rows x 13 month columns 0–12)
-- Verified: 24 cohorts · index 0 = 100% by construction · denominator = cohort
-- size from vw_customers (4,972 rows total).
-- One result column per month index (month_0 … month_12). The v0.64 pivot display
-- enforces a wide minimum cell width, which clipped months 10–12 inside 24 grid
-- units; a plain wide table renders all 13 columns, with the heatmap coming from
-- per-column conditional formatting (fixed 0–15 domain on months 1–12).
-- ============================================================================

WITH cohort_sizes AS (
  SELECT
    cohort_month,
    COUNT(*) AS cohort_customers
  FROM `ecommerce-bi-analytics.full_funnel.vw_customers`
  GROUP BY cohort_month
),
activity AS (
  SELECT
    cohort_month,
    cohort_month_index,
    COUNT(DISTINCT customer_email) AS active_customers
  FROM `ecommerce-bi-analytics.full_funnel.vw_orders_enriched`
  WHERE is_valid_revenue_order = 1
    AND cohort_month_index BETWEEN 0 AND 12
  GROUP BY cohort_month, cohort_month_index
),
joined AS (
  SELECT
    FORMAT_DATE('%Y-%m', a.cohort_month) AS cohort,
    a.cohort_month_index,
    ROUND(SAFE_DIVIDE(a.active_customers, cs.cohort_customers) * 100, 1) AS retention_pct
  FROM activity a
  JOIN cohort_sizes cs USING (cohort_month)
)
SELECT
  cohort,
  MAX(IF(cohort_month_index = 0, retention_pct, NULL)) AS month_0,
  MAX(IF(cohort_month_index = 1, retention_pct, NULL)) AS month_1,
  MAX(IF(cohort_month_index = 2, retention_pct, NULL)) AS month_2,
  MAX(IF(cohort_month_index = 3, retention_pct, NULL)) AS month_3,
  MAX(IF(cohort_month_index = 4, retention_pct, NULL)) AS month_4,
  MAX(IF(cohort_month_index = 5, retention_pct, NULL)) AS month_5,
  MAX(IF(cohort_month_index = 6, retention_pct, NULL)) AS month_6,
  MAX(IF(cohort_month_index = 7, retention_pct, NULL)) AS month_7,
  MAX(IF(cohort_month_index = 8, retention_pct, NULL)) AS month_8,
  MAX(IF(cohort_month_index = 9, retention_pct, NULL)) AS month_9,
  MAX(IF(cohort_month_index = 10, retention_pct, NULL)) AS month_10,
  MAX(IF(cohort_month_index = 11, retention_pct, NULL)) AS month_11,
  MAX(IF(cohort_month_index = 12, retention_pct, NULL)) AS month_12
FROM joined
GROUP BY cohort
ORDER BY cohort;

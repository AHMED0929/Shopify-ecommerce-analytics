-- ============================================================================
-- 07 · Gateway SKU Repeat Test — top-10 first-purchase SKUs vs store baseline
-- Dashboard: Retention & Cohort LTV (bar chart + baseline reference line)
-- Verified against the Power BI page: 73.3% (COLLAR-LED) → 65.5% (CHEW-DENT-12),
-- store baseline 69.5%. DOCUMENTED NULL RESULT: correlation only, no winner.
-- first_sku = alphabetical-min SKU for multi-item first orders.
-- ============================================================================

WITH base AS (
  SELECT
    first_sku,
    lifetime_orders >= 2 AS is_repeat
  FROM `ecommerce-bi-analytics.full_funnel.vw_customers`
  WHERE first_sku IS NOT NULL
),
top10 AS (
  SELECT first_sku
  FROM base
  GROUP BY first_sku
  ORDER BY COUNT(*) DESC
  LIMIT 10
),
baseline AS (
  SELECT ROUND(COUNTIF(lifetime_orders >= 2) * 100 / COUNT(*), 1) AS store_repeat_rate_pct
  FROM `ecommerce-bi-analytics.full_funnel.vw_customers`
)
-- Chart series take their legend names from these SQL aliases (viz column_title styles tables only).
-- Plain words only: parentheses/percent-signs in native column names crash the chart renderer (v0.64).
SELECT
  b.first_sku,
  COUNT(*) AS customers,
  ROUND(COUNTIF(b.is_repeat) * 100 / COUNT(*), 1) AS `Repeat rate`,
  bl.store_repeat_rate_pct AS `Store baseline`
FROM base b
JOIN top10 t USING (first_sku)
CROSS JOIN baseline bl
GROUP BY b.first_sku, bl.store_repeat_rate_pct
ORDER BY `Repeat rate` DESC;

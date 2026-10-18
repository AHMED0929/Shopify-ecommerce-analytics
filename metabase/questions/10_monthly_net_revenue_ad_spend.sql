-- ============================================================================
-- 10 · Monthly Net Revenue & Ad Spend — 24-month seasonality (Sep 2024 – Aug 2026)
-- Dashboard: Full-Funnel Executive (line: net revenue + ad spend)
-- Grain: one row per month. Replaced the daily grain (730 noisy daily spikes).
-- ============================================================================

-- Line-chart series take their legend names from these SQL aliases (viz column_title styles tables only).
SELECT
  DATE_TRUNC(date, MONTH)            AS month,
  ROUND(SUM(ga4_net_revenue), 2)     AS `Net revenue`,
  ROUND(SUM(ad_spend), 2)            AS `Ad spend`
FROM `ecommerce-bi-analytics.full_funnel.vw_daily_full_funnel`
GROUP BY month
ORDER BY month;

-- ============================================================================
-- 02 · Session Funnel — 5 session steps + the 585-grain audit row
-- Dashboard: Full-Funnel Executive (use rows 1–5 for the funnel visual)
-- Verified: 1,327,199 → 417,676 → 45,239 → 23,889 → 11,133
--           step rates 31.5% / 10.8% / 52.8% / 46.6% · overall 0.84%
-- Grain note: purchase events/orders (11,718) > purchase sessions (11,133)
-- by 585 — that is grain, not loss (a session can contain multiple orders).
-- ============================================================================

WITH steps AS (
  SELECT 1 AS step_order, 'Sessions'                AS step, SUM(sessions)              AS value FROM `ecommerce-bi-analytics.full_funnel.vw_daily_full_funnel`
  UNION ALL
  SELECT 2, 'View item',        SUM(view_item_sessions)       FROM `ecommerce-bi-analytics.full_funnel.vw_daily_full_funnel`
  UNION ALL
  SELECT 3, 'Add to cart',      SUM(add_to_cart_sessions)     FROM `ecommerce-bi-analytics.full_funnel.vw_daily_full_funnel`
  UNION ALL
  SELECT 4, 'Begin checkout',   SUM(begin_checkout_sessions)  FROM `ecommerce-bi-analytics.full_funnel.vw_daily_full_funnel`
  UNION ALL
  SELECT 5, 'Purchase (sessions)', SUM(purchase_sessions)     FROM `ecommerce-bi-analytics.full_funnel.vw_daily_full_funnel`
  UNION ALL
  SELECT 6, 'Purchase (orders — audit)', SUM(ga4_purchases)   FROM `ecommerce-bi-analytics.full_funnel.vw_daily_full_funnel`
)
SELECT
  step_order,
  step,
  value,
  ROUND(SAFE_DIVIDE(value, LAG(value) OVER (ORDER BY step_order)) * 100, 1) AS pct_of_previous_step,
  ROUND(SAFE_DIVIDE(value, FIRST_VALUE(value) OVER (ORDER BY step_order)) * 100, 2) AS pct_of_sessions
FROM steps
ORDER BY step_order;

-- For the funnel visual: keep rows WHERE step_order <= 5 (session steps only).
-- Row 6 is the audit row proving the 585 session/order grain gap.

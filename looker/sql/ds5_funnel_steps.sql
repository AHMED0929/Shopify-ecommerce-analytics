-- ============================================================================
-- DS5 · Funnel steps — Looker Studio custom query
-- Source: `ecommerce-bi-analytics.full_funnel.vw_daily_full_funnel`
-- Feeds : Session Funnel (5 steps + step rates)
-- Looker renames: step -> Step · sessions -> Sessions ·
--                 step_rate_prev -> Step rate vs previous ·
--                 step_rate_vs_sessions -> Step rate vs sessions
-- Verified: 1,327,199 -> 417,676 -> 45,239 -> 23,889 -> 11,133
--           step rates 31.5% -> 10.8% -> 52.8% -> 46.6%
-- No trailing semicolon: Looker Studio rejects it.
-- ============================================================================

WITH steps AS (
  SELECT 1 AS step_order, 'Sessions' AS step, SUM(sessions) AS sessions
  FROM `ecommerce-bi-analytics.full_funnel.vw_daily_full_funnel`
  UNION ALL
  SELECT 2, 'View item', SUM(view_item_sessions)
  FROM `ecommerce-bi-analytics.full_funnel.vw_daily_full_funnel`
  UNION ALL
  SELECT 3, 'Add to cart', SUM(add_to_cart_sessions)
  FROM `ecommerce-bi-analytics.full_funnel.vw_daily_full_funnel`
  UNION ALL
  SELECT 4, 'Begin checkout', SUM(begin_checkout_sessions)
  FROM `ecommerce-bi-analytics.full_funnel.vw_daily_full_funnel`
  UNION ALL
  SELECT 5, 'Purchase (sessions)', SUM(purchase_sessions)
  FROM `ecommerce-bi-analytics.full_funnel.vw_daily_full_funnel`
)
SELECT
  step_order,
  step,
  sessions,
  ROUND(
    SAFE_DIVIDE(sessions, LAG(sessions) OVER (ORDER BY step_order)) * 100,
    1
  ) AS step_rate_prev,
  ROUND(
    SAFE_DIVIDE(
      sessions,
      FIRST_VALUE(sessions) OVER (ORDER BY step_order)
    ) * 100,
    2
  ) AS step_rate_vs_sessions
FROM steps
ORDER BY step_order

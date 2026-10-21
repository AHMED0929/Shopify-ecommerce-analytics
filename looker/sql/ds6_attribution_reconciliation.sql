-- ============================================================================
-- DS6 · Attribution reconciliation — Looker Studio custom query
-- Source: `ecommerce-bi-analytics.full_funnel.vw_reconciliation_summary`
-- Feeds : Three-Way Attribution Reconciliation (4 bars)
-- Looker renames: comparison -> Comparison · roas -> ROAS
-- Verified: Platform claimed 1.39 · Paid last-click 1.10 ·
--           Gross MER 4.20 · Net MER 4.15
-- No trailing semicolon: Looker Studio rejects it.
-- ============================================================================

SELECT
  1 AS sort_order,
  'Platform claimed (Meta)' AS comparison,
  ROUND(platform_claimed_roas, 2) AS roas
FROM `ecommerce-bi-analytics.full_funnel.vw_reconciliation_summary`
UNION ALL
SELECT
  2,
  'Paid last-click (GA4)',
  ROUND(paid_last_click_roas, 2)
FROM `ecommerce-bi-analytics.full_funnel.vw_reconciliation_summary`
UNION ALL
SELECT
  3,
  'Gross MER (accounting)',
  ROUND(gross_mer, 2)
FROM `ecommerce-bi-analytics.full_funnel.vw_reconciliation_summary`
UNION ALL
SELECT
  4,
  'Net MER (accounting)',
  ROUND(net_mer, 2)
FROM `ecommerce-bi-analytics.full_funnel.vw_reconciliation_summary`
ORDER BY sort_order

-- ============================================================================
-- KPI · Gross MER — scalar tile for the executive KPI strip (4.20x)
-- Dashboard: Full-Funnel Executive (6-tile strip above the KPI table)
-- ============================================================================
SELECT CONCAT(FORMAT('%.2f', r.gross_mer), 'x') AS gross_mer
FROM `ecommerce-bi-analytics.full_funnel.vw_reconciliation_summary` r;

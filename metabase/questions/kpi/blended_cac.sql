-- ============================================================================
-- KPI · Blended CAC — scalar tile for the executive KPI strip ($299.42)
-- Dashboard: Full-Funnel Executive (6-tile strip above the KPI table)
-- ============================================================================
SELECT CONCAT('$', FORMAT("%'.2f", r.blended_cac)) AS blended_cac
FROM `ecommerce-bi-analytics.full_funnel.vw_reconciliation_summary` r;

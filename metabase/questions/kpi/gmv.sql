-- ============================================================================
-- KPI · GMV — scalar tile for the executive KPI strip ($6.25M)
-- Dashboard: Full-Funnel Executive (6-tile strip above the KPI table)
-- ============================================================================
SELECT CONCAT('$', FORMAT('%.2f', r.shopify_gross_gmv / 1000000), 'M') AS gmv
FROM `ecommerce-bi-analytics.full_funnel.vw_reconciliation_summary` r;

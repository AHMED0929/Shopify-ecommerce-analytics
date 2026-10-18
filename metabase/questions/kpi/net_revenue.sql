-- ============================================================================
-- KPI · Net Revenue — scalar tile for the executive KPI strip ($6.18M)
-- Dashboard: Full-Funnel Executive (6-tile strip above the KPI table)
-- ============================================================================
SELECT CONCAT('$', FORMAT('%.2f', r.shopify_net_revenue / 1000000), 'M') AS net_revenue
FROM `ecommerce-bi-analytics.full_funnel.vw_reconciliation_summary` r;

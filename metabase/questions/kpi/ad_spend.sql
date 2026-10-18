-- ============================================================================
-- KPI · Ad Spend — scalar tile for the executive KPI strip ($1.49M)
-- Dashboard: Full-Funnel Executive (6-tile strip above the KPI table)
-- ============================================================================
SELECT CONCAT('$', FORMAT('%.2f', r.total_ad_spend / 1000000), 'M') AS ad_spend
FROM `ecommerce-bi-analytics.full_funnel.vw_reconciliation_summary` r;

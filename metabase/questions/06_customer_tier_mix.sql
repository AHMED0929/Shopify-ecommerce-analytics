-- ============================================================================
-- 06 · Customer Tier Mix — 1 order / 2 orders / 3+ orders
-- Dashboard: Retention & Cohort LTV (bar chart)
-- Verified: 1,516 / 1,544 / 1,912 customers (30.49% / 31.05% / 38.46%)
-- Repeat revenue share across all tiers = 87.3%.
-- ============================================================================

SELECT
  customer_order_tier,
  COUNT(*) AS customers,
  ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER (), 1) AS customer_share_pct,
  ROUND(SUM(lifetime_net_revenue), 2) AS lifetime_net_revenue,
  ROUND(SUM(lifetime_net_revenue) * 100 / SUM(SUM(lifetime_net_revenue)) OVER (), 1) AS revenue_share_pct
FROM `ecommerce-bi-analytics.full_funnel.vw_customers`
GROUP BY customer_order_tier
ORDER BY CASE customer_order_tier
  WHEN '1 Order (One-Time)' THEN 1
  WHEN '2 Orders' THEN 2
  ELSE 3
END;

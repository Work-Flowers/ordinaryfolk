DROP VIEW IF EXISTS finance_metrics.ltv_cac_by_condition;
CREATE VIEW finance_metrics.ltv_cac_by_condition AS 

WITH all_mrr AS (
	SELECT
		region,
		obs_date,
		condition,
		SUM(CASE WHEN lifecyle = 'New' THEN n_subscriptions ELSE 0 END) AS n_new_subscriptions,
		SUM(current_mrr) AS current_mrr,
		SUM(n_subscriptions) AS current_n_subscriptions
	FROM finance_metrics.subscription_lifecyle_monthly
	WHERE 
		current_mrr > 0
	GROUP BY 1,2,3
),

churn_info AS (
	SELECT
		region,
		obs_date,
		condition,
		n_subscriptions AS n_churned_subscriptions,
		SUM(lagged_mrr) AS churned_mrr		
	FROM finance_metrics.subscription_lifecyle_monthly
	WHERE lifecyle = 'Churn'
	GROUP BY 1,2,3,4
),

gm_inputs AS (
	SELECT
		country,
		date,
		condition,
		amount - refunds - tax_paid_usd AS net_revenue,
		cogs,
		marketing_cost
	FROM finance_metrics.monthly_contribution_margin
)

SELECT	
	am.*,
	ci.n_churned_subscriptions,
	ci.churned_mrr,
	LAG(am.current_n_subscriptions) OVER(
		PARTITION BY am.region, am.condition 
		ORDER BY am.obs_date
	) AS base_n_subscriptions,
	LAG(am.current_mrr) OVER(
		PARTITION BY am.region , am.condition
		ORDER BY am.obs_date
	) AS base_mrr,
	gm.net_revenue,
	gm.cogs,
	gm.marketing_cost
FROM all_mrr AS am
LEFT JOIN churn_info AS ci
	ON am.obs_date = ci.obs_date
	AND am.region = ci.region
	AND am.condition = ci.condition
LEFT JOIN gm_inputs AS gm
	ON am.obs_date = gm.date
	AND am.region = gm.country
	AND am.condition = gm.condition
ORDER BY 1,2
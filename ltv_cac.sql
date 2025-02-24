

WITH all_mrr AS (
	SELECT
		region,
		obs_date,
		SUM(current_mrr) AS current_mrr,
		SUM(n_customers) AS current_n_customers
	FROM finance_metrics.customer_lifecyle_monthly
	WHERE 
		current_mrr > 0
	GROUP BY 1,2
),

churn_info AS (
	SELECT
		region,
		obs_date,
		n_customers AS n_churned_customers,
		SUM(lagged_mrr) AS churned_mrr		
	FROM finance_metrics.customer_lifecyle_monthly
	WHERE lifecyle = 'Churn'
	GROUP BY 1,2,3
),

marketing AS (
	SELECT
		DATE_TRUNC(ms.date, MONTH) AS date,
		LOWER(ms.country_code) AS region,
		SUM(ms.cost_usd) AS cost
	FROM cac.marketing_spend AS ms
	GROUP BY 1,2
)

SELECT	
	am.*,
	ci.n_churned_customers,
	ci.churned_mrr,
	LAG(am.current_n_customers) OVER(
		PARTITION BY am.region 
		ORDER BY am.obs_date
	) AS base_n_customers,
	LAG(am.current_mrr) OVER(
		PARTITION BY am.region 
		ORDER BY am.obs_date
	) AS base_mrr,
	m.cost AS marketing_spend
FROM all_mrr AS am
LEFT JOIN churn_info AS ci
	ON am.obs_date = ci.obs_date
	AND am.region = ci.region
LEFT JOIN marketing AS m
	ON am.obs_date = m.date
	AND am.region = m.region
ORDER BY 1,2
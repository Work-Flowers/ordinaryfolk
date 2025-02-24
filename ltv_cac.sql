

WITH all_mrr AS (
	SELECT
		region,
		obs_date,
		SUM(current_mrr) AS current_mrr,
		COUNT(DISTINCT customer_id) AS current_n_customers
	FROM finance_metrics.customer_lifecyle_monthly
	WHERE 
		current_mrr > 0
	GROUP BY 1,2
),

churn_info AS (
	SELECT
		region,
		obs_date,
		n_customers,
		SUM(lagged_mrr) AS churned_mrr		
	FROM finance_metrics.customer_lifecyle_monthly
	WHERE lifecyle = 'Churn'
	GROUP BY 1,2,3
),

lagged_base AS (
	SELECT
		region,
		obs_date,
		LAG(SUM(n_customers)) OVER (PARTITION BY region ORDER BY obs_date) AS base_n_customers,
		LAG(SUM(current_mrr)) OVER (PARTITION BY region ORDER BY obs_date) AS base_mrr
	FROM finance_metrics.customer_lifecyle_monthly
	WHERE lifecyle <> 'Churn'
	GROUP BY 1,2
)


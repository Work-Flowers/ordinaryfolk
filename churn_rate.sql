WITH customers AS (
	SELECT
		region,
		customer_id,
		obs_date,
		MIN(obs_date) OVER(PARTITION BY customer_id) AS acq_date,
		SUM(mrr_usd) AS mrr_usd,
		LEAD(SUM(mrr_usd)) OVER (
			PARTITION BY customer_id
			ORDER BY obs_date
		) AS leading_mrr,
		LAG(SUM(mrr_usd)) OVER (
			PARTITION BY customer_id
			ORDER BY obs_date
		) AS lagged_mrr
	FROM all_stripe.subscription_metrics
	GROUP BY 1,2,3
)
SELECT
	region,
	obs_date,
	COUNT(DISTINCT CASE WHEN mrr_usd = 0 THEN customer_id END) AS n_churned,
	COUNT(DISTINCT customer_id) AS n_customers,
	LAG(COUNT(DISTINCT customer_id)) OVER (
		PARTITION BY region
		ORDER BY obs_date
	) AS lagged_n_customers
FROM customers
GROUP BY 1,2
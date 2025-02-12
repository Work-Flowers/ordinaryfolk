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
	COUNT(DISTINCT customer_id) AS n_customers,
	LAG(COUNT(DISTINCT customer_id)) OVER (
		PARTITION BY region
		ORDER BY obs_date
	) AS lagged_n_customers,
	obs_date,
	SUM(CASE WHEN mrr_usd > 0 THEN 1 ELSE 0 END) AS churned_customers
	
    lagged_mrr,
    leading_mrr,
	CASE 
		WHEN obs_date = acq_date THEN 'New'
		WHEN mrr_usd = 0 AND (lagged_mrr > 0 OR lagged_mrr IS NULL) THEN 'Churned'
		WHEN mrr_usd > 0 AND obs_date > acq_date AND lagged_mrr = 0 THEN 'Reactivated'
		WHEN mrr_usd = lagged_mrr THEN 'MRR Flat'
		WHEN mrr_usd > lagged_mrr THEN 'MRR Expansion'
		WHEN mrr_usd < lagged_mrr THEN 'MRR Contraction'
		END AS segment
FROM customers
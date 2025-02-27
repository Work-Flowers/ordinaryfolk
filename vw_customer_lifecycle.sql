DROP VIEW IF EXISTS finance_metrics.customer_lifecyle;
CREATE VIEW finance_metrics.customer_lifecyle AS 

WITH customers_monthly AS (
	SELECTœ
		region,
		customer_id,
		CASE 
			WHEN mrr_usd > 0 THEN obs_date
			WHEN obs_date = DATE_TRUNC(obs_date, MONTH) THEN obs_date
			ELSE DATE_TRUNC(DATE_ADD(obs_date, INTERVAL 1 MONTH), MONTH)
			END AS obs_date,
		SUM(mrr_usd) AS mrr_usd		
	FROM all_stripe.subscription_metrics
	WHERE 
		(obs_date = DATE_TRUNC(obs_date, MONTH) OR mrr_usd = 0)
	GROUP BY 1,2,3
	ORDER BY 2,3
),

customer_lifecycle AS (
	SELECT
		region,
		customer_id,
		obs_date,
		mrr_usd AS current_mrr,
		MIN(obs_date) OVER(PARTITION BY customer_id) AS acq_date,
		LAG(mrr_usd) OVER (
			PARTITION BY customer_id
			ORDER BY obs_date
		) AS lagged_mrr
	FROM customers_monthly

),

customers_tagged AS(
	SELECT
		region,
		obs_date,
		acq_date,
		customer_id,
		current_mrr,
		lagged_mrr,
		CASE 
			WHEN obs_date = acq_date THEN 'New'
			WHEN current_mrr = 0 AND lagged_mrr > 0 THEN 'Churned'
			WHEN current_mrr > 0 AND (lagged_mrr IS NULL OR lagged_mrr = 0) THEN 'Reactivated'
			WHEN current_mrr > lagged_mrr THEN 'Expansion'
			WHEN current_mrr < lagged_mrr THEN 'Contraction'
			WHEN current_mrr = lagged_mrr THEN 'Retained'
			END AS lifecyle
	FROM customer_lifecycle
)

SELECT 
	region,
	obs_date,
	lifecyle,
	COUNT(DISTINCT customer_id) AS n_customers,
	SUM(current_mrr) AS current_mrr,
	SUM(lagged_mrr) AS lagged_mrr
FROM customers_tagged
GROUP BY 1,2,3
ORDER BY 1,2,3
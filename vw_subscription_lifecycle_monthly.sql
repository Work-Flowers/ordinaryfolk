DROP VIEW IF EXISTS finance_metrics.subscription_lifecyle_monthly;
CREATE VIEW finance_metrics.subscription_lifecyle_monthly AS 

-- one row per subscription_id x condition per month in which it was active
-- also include one row with 0 MRR for the first month AFTER cancellation, so we can identify churn 
WITH subscriptions_monthly AS (
	SELECT
		region,
		subscription_id,
		condition,
		CASE 
			WHEN mrr_usd > 0 THEN obs_date
			WHEN obs_date = DATE_TRUNC(obs_date, MONTH) THEN obs_date
			ELSE DATE_TRUNC(DATE_ADD(obs_date, INTERVAL 1 MONTH), MONTH)
			END AS obs_date,
		SUM(mrr_usd) AS mrr_usd		
	FROM all_stripe.subscription_metrics
	WHERE 
		(obs_date = DATE_TRUNC(obs_date, MONTH) OR mrr_usd = 0)
	GROUP BY 1,2,3,4
),

-- find the lagged MRR for each subscription
subscriptions_lagged AS (
	SELECT
		region,
		subscription_id,
		condition,
		obs_date,
		mrr_usd AS current_mrr,
		MIN(obs_date) OVER (PARTITION BY subscription_id, condition) AS acq_date,
		LAG(mrr_usd) OVER (
			PARTITION BY subscription_id, condition
			ORDER BY obs_date
		) AS lagged_mrr
	FROM subscriptions_monthly

),

-- now assign lifecycle category
subscriptions_lifecyle AS(
	SELECT
		region,
		obs_date,
		acq_date,
		subscription_id,
		condition,
		current_mrr,
		lagged_mrr,
		CASE 
			WHEN obs_date = acq_date THEN 'New'
			WHEN current_mrr = 0 AND lagged_mrr > 0 THEN 'Churn'
			WHEN current_mrr > 0 AND (lagged_mrr IS NULL OR lagged_mrr = 0) THEN 'Reactivation'
			WHEN current_mrr > lagged_mrr THEN 'Expansion'
			WHEN current_mrr < lagged_mrr THEN 'Contraction'
			WHEN current_mrr = lagged_mrr THEN 'Retention'
			END AS lifecyle
	FROM subscriptions_lagged
	WHERE current_mrr > 0 OR lagged_mrr IS NOT NULL
)

SELECT 
	region,
	obs_date,
	lifecyle,
	condition,
	COUNT(DISTINCT subscription_id) AS n_subscriptions,
	SUM(current_mrr) AS current_mrr,
	SUM(lagged_mrr) AS lagged_mrr
FROM subscriptions_lifecyle
GROUP BY 1,2,3,4
WITH acq_dates AS (
	SELECT
		ch.region,
		ch.customer_id,
		MIN(DATE_TRUNC(ch.created, month)) AS acquired_date
	FROM all_stripe.charge AS ch
	WHERE ch.status = 'succeeded'
	GROUP BY 1,2
),

subscriptions AS (
	SELECT
		obs_date AS date,
		region AS country,
		COUNT(DISTINCT customer_id) AS total_subscribers,
		SUM(mrr_usd) AS mrr
	FROM all_stripe.subscription_metrics
	WHERE 
		1 = 1
		AND obs_date = DATE_TRUNC(obs_date, month) 
		AND mrr_usd > 0
	GROUP BY 1,2
)

SELECT
	cm.date,
	cm.country,
	cm.marketing_cost,
	cm.amount AS revenue,
	cm.cogs,
	cm.cashback,
	cm.packaging,
	cm.tax_paid_usd,
	cm.refunds,
	cm.payment_gateway_fees,
	cm.delivery_cost,
	subscriptions.mrr,
	subscriptions.total_subscribers,
	COUNT(DISTINCT ad.customer_id) AS n_new_customers
FROM finance_metrics.monthly_contribution_margin AS cm
LEFT JOIN acq_dates AS ad
	ON DATE(cm.date) = DATE(ad.acquired_date)
	AND cm.country = ad.region
LEFT JOIN subscriptions
	ON cm.date = subscriptions.date
	AND cm.country = subscriptions.country
WHERE
	cm.purchase_type = 'Subscription'
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13
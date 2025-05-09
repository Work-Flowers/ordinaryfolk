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
	subscriptions.mrr,
	subscriptions.total_subscribers,
	SUM(cm.marketing_cost) AS marketing_cost,
	SUM(cm.gross_revenue) AS revenue,
	SUM(cm.cogs) AS cogs,
	SUM(cm.cashback) AS cashback,
	SUM(cm.packaging) AS packaging,
	SUM(cm.tax_paid_usd) AS tax_paid_usd,
	SUM(cm.refunds) AS refunds,
	SUM(cm.gateway_fees) AS payment_gateway_fees,
	SUM(cm.delivery_cost) AS delivery_cost,	
	COUNT(DISTINCT ad.customer_id) AS n_new_customers
FROM finance_metrics.monthly_contribution_margin AS cm
LEFT JOIN acq_dates AS ad
	ON DATE(cm.date) = DATE(ad.acquired_date)
	AND cm.customer_id = ad.customer_id
	AND cm.country = ad.region
LEFT JOIN subscriptions
	ON cm.date = subscriptions.date
	AND cm.country = subscriptions.country
WHERE
	cm.purchase_type = 'Subscription'
GROUP BY 1,2,3,4
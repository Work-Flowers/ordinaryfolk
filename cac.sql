WITH marketing AS (
	SELECT
		DATE_TRUNC(date, MONTH) AS date,
		UPPER(country_code) AS country,
		SUM(cost_usd) AS marketing_spend
	FROM cac.marketing_spend
	GROUP BY 1,2
),

acq_dates AS (
	SELECT
		ch.region,
		ch.customer_id,
		MIN(DATE_TRUNC(ch.created, month)) AS acquired_date
	FROM all_stripe.charge AS ch
	WHERE ch.status = 'succeeded'
	GROUP BY 1,2
),

cm AS (
	SELECT
		DATE_TRUNC(purchase_date, month) AS date,
		region AS country,
		SUM(COALESCE(line_item_amount_usd, total_charge_amount_usd)) AS revenue,
		SUM(cogs) AS cogs,
		SUM(gst_vat * COALESCE(line_item_amount_usd, total_charge_amount_usd)) AS gst_vat_usd,
		SUM(refund_rate * COALESCE(line_item_amount_usd, total_charge_amount_usd)) AS refund_usd
		
	FROM finance_metrics.contribution_margin
	WHERE purchase_type = 'Subscription'
	GROUP BY 1,2
),

subscriptions AS (
	SELECT
		obs_date AS date,
		region AS country,
		SUM(mrr_usd) AS mrr
	FROM all_stripe.subscription_metrics
	WHERE 
		1 = 1
		AND obs_date = DATE_TRUNC(obs_date, month) 
		AND mrr_usd = 0
	GROUP BY 1,2
)

SELECT
	mar.date,
	mar.country,
	mar.marketing_spend,
	cm.revenue,
	cm.cogs,
	cm.gst_vat_usd,
	cm.refund_usd,
	subscriptions.mrr,
	COUNT(DISTINCT ad.customer_id) AS n_new_customers
FROM marketing AS mar
LEFT JOIN acq_dates AS ad
	ON DATE(mar.date) = DATE(ad.acquired_date)
	AND LOWER(mar.country) = LOWER(ad.region)
LEFT JOIN cm
	ON mar.date = cm.date
	AND LOWER(mar.country) = LOWER(cm.country)
LEFT JOIN subscriptions
	ON mar.date = subscriptions.date
	AND LOWER(mar.country) = LOWER(subscriptions.country)
GROUP BY 1,2,3,4,5,6,7,8
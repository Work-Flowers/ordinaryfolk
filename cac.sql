WITH marketing AS (
	SELECT
		date,
		UPPER(country_code) AS country,
		SUM(cost_usd) AS marketing_spend
	FROM cac.marketing_spend
	GROUP BY 1,2
),

acq_dates AS (
	SELECT
		ch.region,
		ch.customer_id,
		MIN(ch.created) AS acquired_date
	FROM all_stripe.charge AS ch
	WHERE ch.status = 'succeeded'
	GROUP BY 1,2
)

SELECT
	mar.date,
	mar.country,
	mar.marketing_spend,
	COUNT(DISTINCT ad.customer_id) AS n_new_customers
FROM marketing AS mar
LEFT JOIN acq_dates AS ad
	ON DATE(mar.date) = DATE(ad.acquired_date)
	AND LOWER(mar.country) = LOWER(ad.region)
GROUP BY 1,2,3
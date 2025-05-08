WITH marketing AS (
	SELECT
		DATE_TRUNC(date, MONTH) AS date,
		LOWER(country_code) AS country,
		ROUND(SUM(cost_usd), 0) AS spend,
		ROUND(SUM(impressions), 0) AS impressions,
		ROUND(SUM(clicks), 0) AS clicks
	FROM cac.marketing_spend
	GROUP BY 1,2
),

all_keys AS (
	
	SELECT DISTINCT 
		date,
		country
	FROM marketing
	
	UNION DISTINCT
	
	SELECT DISTINCT
		DATE_TRUNC(purchase_date, MONTH) AS date,
		region AS country
	FROM finance_metrics.contribution_margin
)


SELECT 
	k.date,
	k.country,
	COALESCE(marketing.spend, 0) AS marketing_spend,
	COUNT(DISTINCT CASE WHEN cm.new_existing = 'New' THEN cm.customer_id END) AS n_new_customers
FROM all_keys AS k
LEFT JOIN finance_metrics.contribution_margin AS cm
	ON k.date = cm.purchase_date
	AND k.country = cm.region
LEFT JOIN marketing		
	ON k.date = marketing.date
	AND k.country = marketing.country
WHERE 
	k.date >= DATE_SUB(DATE_TRUNC(CURRENT_DATE, MONTH), INTERVAL 12 MONTH)
	AND k.date < DATE_TRUNC(CURRENT_DATE, MONTH)
GROUP BY 1,2,3
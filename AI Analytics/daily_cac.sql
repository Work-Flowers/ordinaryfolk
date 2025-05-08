WITH marketing AS (
	SELECT
		date,
		LOWER(country_code) AS country,
		SUM(ROUND(cost_usd, 2)) AS spend,
		SUM(impressions) AS impressions,
		SUM(ROUND(clicks, 0)) AS clicks
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
		purchase_date AS date,
		region AS country
	FROM finance_metrics.contribution_margin
)


SELECT 
	k.date,
	k.country,
	marketing.spend AS marketing_spend,
	SUM(COALESCE(cm.line_item_amount_usd, cm.total_charge_amount_usd)) AS revenue,
	COUNT(DISTINCT CASE WHEN cm.new_existing = 'New' THEN cm.customer_id END) AS n_new_customers
FROM all_keys AS k
LEFT JOIN finance_metrics.contribution_margin AS cm
	ON k.date = cm.purchase_date
	AND k.country = cm.region
LEFT JOIN marketing		
	ON k.date = marketing.date
	AND k.country = marketing.country
	
GROUP BY 1,2,3
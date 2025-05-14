DROP VIEW IF EXISTS cac.daily_roas;
CREATE VIEW cac.daily_roas AS

WITH marketing AS (
	SELECT
		date,
		CASE 
			WHEN condition IN ('ED', 'PE') THEN 'ED + PE'
			WHEN condition IS NOT NULL THEN condition
			ELSE 'N/A'
			END AS condition,
		brand,
		LOWER(country_code) AS country,
		SUM(ROUND(cost_usd, 2)) AS spend,
		SUM(impressions) AS impressions,
		SUM(ROUND(clicks, 0)) AS clicks
	FROM cac.marketing_spend
	GROUP BY 1,2,3,4
),

all_keys AS (
	
	SELECT DISTINCT 
		date,
		condition,
		country,
		brand
	FROM marketing
	
	UNION DISTINCT
	
	SELECT DISTINCT
		purchase_date AS date,
		CASE 
			WHEN condition IN ('ED', 'PE') THEN 'ED + PE'
			WHEN condition IS NOT NULL THEN condition
			ELSE 'N/A'
			END AS condition,
		region AS country,
		brand
	FROM finance_metrics.contribution_margin
)


SELECT 
	k.date,
	k.country,
	k.condition,
	k.brand,
	marketing.spend AS marketing_spend,
	marketing.impressions,
	marketing.clicks,
	SUM(COALESCE(cm.line_item_amount_usd, cm.total_charge_amount_usd)) AS revenue,
	COUNT(DISTINCT CASE WHEN cm.new_existing = 'New' THEN cm.customer_id END) AS n_new_customers,
	SUM(CASE WHEN cm.new_existing = 'New' THEN COALESCE(cm.line_item_amount_usd, cm.total_charge_amount_usd) ELSE 0 END) AS first_purchase_amount
FROM all_keys AS k
LEFT JOIN finance_metrics.contribution_margin AS cm
	ON k.date = cm.purchase_date
	AND k.brand = cm.brand
	AND k.condition = (
		CASE 
			WHEN cm.condition IN ('ED', 'PE') THEN 'ED + PE'
			WHEN cm.condition IS NOT NULL THEN cm.condition
			ELSE 'N/A'
			END
		)
	AND k.country = cm.region
LEFT JOIN marketing		
	ON k.date = marketing.date
	AND k.condition = marketing.condition
	AND k.country = marketing.country
	AND k.brand = marketing.brand
	
GROUP BY 1,2,3,4,5,6,7
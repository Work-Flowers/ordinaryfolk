DROP VIEW IF EXISTS cac.daily_roas;
CREATE VIEW cac.daily_roas AS


WITH marketing AS (
	SELECT
		date,
		COALESCE(condition, 'N/A') AS condition,
		LOWER(country_code) AS country,
		SUM(cost_usd) AS spend
	FROM cac.marketing_spend
	GROUP BY 1,2,3
),

all_keys AS (
	
	SELECT DISTINCT 
		date,
		condition,
		country
	FROM marketing
	
	UNION DISTINCT
	
	SELECT DISTINCT
		purchase_date AS date,
		COALESCE(condition, 'N/A') AS condition,
		region AS country
	FROM finance_metrics.contribution_margin
)


SELECT 
	k.date,
	k.country,
	k.condition,
	marketing.spend AS marketing_spend,
	SUM(COALESCE(cm.line_item_amount_usd, cm.total_charge_amount_usd)) AS revenue,
	COUNT(DISTINCT CASE WHEN cm.new_existing = 'New' THEN cm.customer_id END) AS n_new_customers,
	SUM(CASE WHEN cm.new_existing = 'New' THEN COALESCE(cm.line_item_amount_usd, cm.total_charge_amount_usd) ELSE 0 END) AS first_purchase_amount
FROM all_keys AS k
LEFT JOIN finance_metrics.contribution_margin AS cm
	ON k.date = cm.purchase_date
	AND k.condition = COALESCE(cm.condition, 'N/A')
	AND k.country = cm.region
LEFT JOIN marketing		
	ON k.date = marketing.date
	AND k.condition = marketing.condition
	AND k.country = marketing.country
	
GROUP BY 1,2,3,4

SELECT
	cm.region,
	cm.sales_channel,
	DATE_TRUNC(cm.purchase_date, MONTH) AS purchase_month,
	cm.purchase_type,
	CASE 
		WHEN cm.product_name LIKE 'Telecons%' THEN 'Teleconsultation'
		ELSE cm.condition
		END AS category,
	COUNT(DISTINCT cm.customer_id) AS n_customers,
	SUM(COALESCE(cm.line_item_amount_usd, cm.total_charge_amount_usd)) AS revenue_usd,
	SUM(COALESCE(cm.line_item_amount_usd, cm.total_charge_amount_usd) * fx.fx_to_usd) AS revenue_local
FROM finance_metrics.contribution_margin AS cm
LEFT JOIN ref.fx_rates AS fx
	ON cm.currency = fx.currency
WHERE cm.region = 'sg'
GROUP BY 1,2,3,4,5
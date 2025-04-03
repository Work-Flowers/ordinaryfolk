SELECT 
	cm.sales_channel,
	cm.region,	
	DATE_TRUNC(cm.purchase_date, MONTH) AS purchase_month,
	cm.purchase_type,
	cm.billing_reason,
	cm.currency,
	cm.new_existing,
	COUNT(DISTINCT cm.customer_id) AS n_customers,
	SUM(COALESCE(line_item_amount_usd, total_charge_amount_usd)) AS revenue_usd,
	SUM(COALESCE(line_item_amount_usd, total_charge_amount_usd) / fx.fx_to_usd) AS revenue_local,
	SUM(COALESCE(line_item_amount_usd, total_charge_amount_usd) * refund_rate) AS refunds_usd,
	SUM(COALESCE(line_item_amount_usd, total_charge_amount_usd) * (1 - 1 / (1 + gst_vat))) AS gst_vat_usd,
	SUM(packaging) AS packaging
FROM finance_metrics.contribution_margin AS cm
LEFT JOIN ref.fx_rates AS fx
	ON cm.currency = fx.currency
GROUP BY 1,2,3,4,5,6,7
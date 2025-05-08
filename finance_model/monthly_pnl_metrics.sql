SELECT 
	cm.sales_channel,
	cm.country,	
	cm.purchase_month,
	cm.purchase_type,
	cm.billing_reason,
	cm.currency,
	cm.new_existing,
	cm.condition,
	COUNT(DISTINCT cm.customer_id) AS n_customers,
	COUNT(DISTINCT cm.charge_id) AS n_charges,
	SUM(cm.revenue) AS revenue_usd,
	SUM(cm.revenue * fx.fx_to_usd) AS revenue_local,
	SUM(cm.cogs) AS cogs_usd,
	SUM(cm.refunds) AS refunds_usd,
	SUM(cm.tax_paid_usd) AS gst_vat_usd,
	SUM(cm.packaging) AS packaging_usd,
	SUM(cm.payment_gateway_fees) AS payment_gateway_fees_usd,
	SUM(cm.prorated_marketing_cost) AS marketing_cost_usd,
	SUM(cm.prorated_delivery_cost) AS delivery_cost_usd,
	SUM(cm.dispensing_fees) AS dispensing_fees_usd,
	SUM(cm.staff_cost) AS staff_cost_usd,
	SUM(cm.teleconsultation_fees) AS teleconsultation_fees_usd,
	SUM(cm.operating_expense) AS operating_expense_usd
FROM finance_metrics.cm3 AS cm
LEFT JOIN ref.fx_rates AS fx
	ON cm.currency = fx.currency
GROUP BY 1,2,3,4,5,6,7,8
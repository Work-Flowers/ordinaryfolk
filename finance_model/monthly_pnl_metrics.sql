SELECT 
	cm.sales_channel,
	cm.country,	
	cm.purchase_month,
	cm.purchase_type,
	cm.billing_reason,
	cm.currency,
	cm.new_existing,
	COUNT(DISTINCT cm.customer_id) AS n_customers,
	SUM(cm.revenue),
	SUM(cm.revenue / fx.fx_to_usd) AS revenue_local,
	SUM(cm.refunds) AS refunds_usd,
	SUM(cm.gst_vat) AS gst_vat_usd,
	SUM(cm.packaging) AS packaging,
	SUM(cm.payment_gateway_fees) AS payment_gateway_fees,
	SUM(cm.prorated_marketing_cost) AS marketing_cost,
	SUM(cm.prorated_delivery_cost) AS delivery_cost
FROM finance_metrics.cm3 AS cm
LEFT JOIN ref.fx_rates AS fx
	ON cm.currency = fx.currency
GROUP BY 1,2,3,4,5,6,7



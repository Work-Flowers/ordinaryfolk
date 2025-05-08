SELECT
	cm.date,
	cm.country,
	cm.condition,
	cm.new_existing,
	cm.purchase_type,
	cm.sales_channel,
	ROUND(SUM(cm.gross_revenue), 0) AS gross_revenue,
	ROUND(SUM(cm.net_revenue), 0) AS net_revenue,
	ROUND(SUM(COALESCE(cm.cogs, 0)), 0) AS cogs,
	ROUND(SUM(cm.gross_profit), 0) AS gross_profit,
	ROUND(SUM(cm.operating_expense), 0) AS operating_expense,
	ROUND(SUM(cm.staff_cost), 0) AS staff_cost,
	ROUND(SUM(cm.ebitda), 0) AS ebitda,
	SUM(cm.n_orders) AS n_orders

FROM finance_metrics.monthly_contribution_margin AS cm
WHERE 
	cm.date >= DATE_SUB(DATE_TRUNC(CURRENT_DATE, MONTH), INTERVAL 12 MONTH)
	AND cm.date < DATE_TRUNC(CURRENT_DATE, MONTH)
GROUP BY 1,2,3,4,5,6
DROP VIEW IF EXISTS finance_metrics.cod_sg_orders_all;
CREATE VIEW finance_metrics.cod_sg_orders_all AS 

SELECT
	a.purchase_date AS date,
	a.email,
	LOWER(a.currency) AS currency,
	a.quantity,
	a.product_id,
	a.purchase_amount
FROM google_sheets.cod_sg_revenue_pre_2025 AS a

UNION ALL

SELECT
	b.date,
	b.email,
	LOWER(b.currency) AS currency,
	b.quantity,
	b.product_id,
	b.revenue AS purchase_amount
FROM google_sheets.cod_sg_revenue AS b;
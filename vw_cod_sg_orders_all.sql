DROP VIEW IF EXISTS google_sheets.cod_sg_orders_all;
CREATE VIEW google_sheets.cod_sg_orders_all AS 

SELECT
	a.purchase_date AS date,
	LOWER(a.currency) AS currency,
	a.quantity,
	a.product_id,
	a.purchase_amount
FROM google_sheets.cod_sg_revenue_pre_2025 AS a

UNION ALL

SELECT
	b.date,
	LOWER(b.currency) AS currency,
	b.quantity,
	b.product_id,
	b.revenue AS purchase_amount
FROM google_sheets.cod_sg_revenue AS b;
DROP VIEW IF EXISTS finance_metrics.cod_hk_orders_all;
CREATE VIEW finance_metrics.cod_hk_orders_all AS 

WITH hk_skus AS (
	SELECT DISTINCT
		sku,
		id
	FROM google_sheets.hk_product_cost_stripe
	
)

SELECT
	a.purchase_date AS date,
	a.email,
	LOWER(a.currency) AS currency,
	a.quantity,
	a.product_id,
	a.purchase_amount
FROM google_sheets.cod_hk_revenue_pre_2025 AS a

UNION ALL

SELECT
	aw.pai_jian_ri_qi_delivery_date AS date,
	aw.email,
	'hkd' AS currency,
	li.quantity,
	pc.id AS product_id,
	li.revenue AS purchase_amount
FROM google_sheets.sf_express_airway_bills AS aw
LEFT JOIN google_sheets.sf_express_line_items AS li
	ON aw.yun_dan_bian_hao_awb_no_ = li.yun_dan_bian_hao_awb_no_
LEFT JOIN hk_skus AS pc
	ON LOWER(li.sku) = LOWER(pc.sku);
DROP VIEW IF EXISTS finance_metrics.cod_hk_orders_all;
CREATE VIEW finance_metrics.cod_hk_orders_all AS 

WITH hk_skus AS (
	SELECT
		sku,
		id,
		effective_from AS from_date,
		COALESCE(LEAD(effective_from, 1) OVER (PARTITION BY id ORDER BY effective_from) - 1, '9999-12-31') AS to_date
	FROM google_sheets.hk_product_cost_stripe
)

SELECT
	a.purchase_date AS date,
	a.email,
	LOWER(a.currency) AS currency,
	a.quantity,
	a.product_id,
	a.purchase_amount,
	0 AS payment_gateway_fees
FROM google_sheets.cod_hk_revenue_pre_2025 AS a

UNION ALL

SELECT
	aw.pai_jian_ri_qi_delivery_date AS date,
	aw.email,
	'hkd' AS currency,
	li.quantity,
	pc.id AS product_id,
	li.revenue AS purchase_amount,
	aw.fu_wu_fei_service_charge * li.revenue / SUM(li.revenue) OVER(PARTITION BY aw.yun_dan_bian_hao_awb_no_) AS payment_gateway_fees
FROM google_sheets.sf_express_airway_bills AS aw
LEFT JOIN google_sheets.sf_express_line_items AS li
	ON aw.yun_dan_bian_hao_awb_no_ = li.yun_dan_bian_hao_awb_no_
LEFT JOIN hk_skus AS pc
	ON LOWER(li.sku) = LOWER(pc.sku)
	AND aw.pai_jian_ri_qi_delivery_date BETWEEN pc.from_date AND pc.to_date;
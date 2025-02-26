DROP VIEW IF EXISTS all_stripe.product_cost;
CREATE VIEW all_stripe.product_cost AS

WITH manual_inputs AS (
	SELECT
		id AS product_id,
		cost_box,
		packaging_cost
	FROM google_sheets.sg_product_cost_stripe
	
	UNION ALL
	
	SELECT
		id AS product_id,
		cost_box,
		packaging_cost
	FROM google_sheets.hk_product_cost_stripe
	
	UNION ALL
	
	SELECT
		id AS product_id,
		cost_box,
		packaging_cost
	FROM google_sheets.jp_product_cost_stripe
)

SELECT
	px.region,
	mi.product_id,
	px.id AS price_id,
	px.currency,
	mi.cost_box * COALESCE(CAST(JSON_EXTRACT_SCALAR(px.metadata, '$.boxes') AS FLOAT64), 1) AS cogs,
	packaging_cost AS packaging,
	CASE 
		WHEN px.region = 'hk' THEN 0
		WHEN px.region = 'sg' THEN 0.09
		WHEN px.region = 'jp' THEN 0.10
		END AS gst_vat,
	.02 AS cashback
FROM manual_inputs AS mi
LEFT JOIN all_stripe.price AS px
	ON mi.product_id = px.product_id
	
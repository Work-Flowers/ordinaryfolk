DROP VIEW IF EXISTS all_stripe.product_cost;
CREATE VIEW all_stripe.product_cost AS

WITH manual_inputs AS (
	SELECT
		'sg' AS region,
		id AS product_id,
		cost_box,
		packaging_cost,
		effective_date AS from_date,
		COALESCE(LEAD(effective_date, 1) OVER (PARTITION BY id ORDER BY effective_date), '9999-12-31') AS to_date
	FROM google_sheets.sg_product_cost_stripe
	
	UNION ALL
	
	SELECT
		'hk' AS region,
		id AS product_id,
		cost_box,
		packaging_cost,
		effective_from AS from_date,
		COALESCE(LEAD(effective_from, 1) OVER (PARTITION BY id ORDER BY effective_from), '9999-12-31') AS to_date
	FROM google_sheets.hk_product_cost_stripe
	
	UNION ALL
	
	SELECT
		'jp' AS region,
		id AS product_id,
		cost_box,
		packaging_cost,
		effective_from AS from_date,
		COALESCE(LEAD(effective_from, 1) OVER (PARTITION BY id ORDER BY effective_from), '9999-12-31') AS to_date
	FROM google_sheets.jp_product_cost_stripe
)

SELECT
	px.region,
	mi.product_id,
	px.id AS price_id,
	mi.from_date,
	mi.to_date,
	px.currency,
	mi.cost_box * COALESCE(CAST(JSON_EXTRACT_SCALAR(px.metadata, '$.boxes') AS FLOAT64), 1) AS cogs,
	packaging_cost AS packaging,
	.02 AS cashback
FROM manual_inputs AS mi
LEFT JOIN all_stripe.price AS px
	ON mi.product_id = px.product_id
	AND mi.region = px.region
	
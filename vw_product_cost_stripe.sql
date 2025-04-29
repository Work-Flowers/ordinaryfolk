DROP VIEW IF EXISTS all_stripe.product_cost;
CREATE VIEW all_stripe.product_cost AS

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
FROM all_stripe.product_cost_per_box AS mi
LEFT JOIN all_stripe.price AS px
	ON mi.product_id = px.product_id
	AND mi.region = px.region
	
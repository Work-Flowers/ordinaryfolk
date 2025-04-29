
DROP VIEW IF EXISTS all_stripe.product_cost_per_box;
CREATE VIEW all_stripe.product_cost_per_box AS (

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
);

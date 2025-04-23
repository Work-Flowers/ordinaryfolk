WITH price_condition AS (
	SELECT
		px.id AS price_id,
		px.product_id,
		pr.name AS product_name,
		JSON_VALUE(pr.metadata, '$.condition') AS condition
	FROM all_stripe.price AS px
	INNER JOIN all_stripe.product AS pr
		ON px.product_id = pr.id
		AND pr.active IS TRUE	

)

SELECT
	DATE(ch.created) AS date,
	ch.region,
	ch.id AS charge_id,
	ch.description AS charge_description,
	ch.payment_intent_id,
	pi.description AS payment_intent_description,
	pi_price_id.product_name AS product_from_pi_price_id,
	pi_price_id.condition AS condition_from_pi_price_id,
	stripe_price_ids.product_name AS product_from_pi_stripe_price_id,
	stripe_price_ids.condition AS condition_from_pi_stripe_price_id,
	ch.currency,
	ch.amount / COALESCE(sub.subunits, 100) AS charge_amount_local
FROM all_stripe.charge AS ch
INNER JOIN all_stripe.payment_intent AS pi
	ON ch.payment_intent_id = pi.id
LEFT JOIN ref.stripe_currency_subunits AS sub
	ON ch.currency = sub.currency
LEFT JOIN price_condition AS pi_price_id
	ON JSON_EXTRACT_SCALAR(pi.metadata, '$.paymentIntentPriceId') = pi_price_id.price_id
LEFT JOIN price_condition AS stripe_price_ids
	ON JSON_EXTRACT_SCALAR(pi.metadata, '$.stripePriceIds') = stripe_price_ids.price_id
WHERE
	1 = 1
	AND ch.status = 'succeeded'
	AND ch.invoice_id IS NULL
	-- at least one of the two price_id metadata fields is populated
	AND COALESCE(JSON_EXTRACT_SCALAR(pi.metadata, '$.paymentIntentPriceId'), JSON_EXTRACT_SCALAR(pi.metadata, '$.stripePriceIds')) IS NOT NULL
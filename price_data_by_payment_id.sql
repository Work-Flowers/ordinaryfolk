SELECT 
	pi.region,
	pi.id AS payment_intent_id,
	px.product_id,
	px.id AS price_id,
	px.nickname AS price_nickname,
	JSON_EXTRACT_SCALAR(px.metadata, '$.boxes') AS n_boxes
FROM all_stripe.payment_intent AS pi
LEFT JOIN all_stripe.charge AS ch
	ON pi.id = ch.payment_intent_id
LEFT JOIN all_stripe.invoice AS inv
	ON ch.invoice_id = inv.id
LEFT JOIN all_stripe.invoice_line_item AS ii
	ON ch.invoice_id = ii.invoice_id
LEFT JOIN all_stripe.price AS px
	ON COALESCE(ii.price_id, JSON_EXTRACT_SCALAR(pi.metadata, '$.paymentIntentPriceId'), JSON_EXTRACT_SCALAR(pi.metadata, '$.stripePriceIds')) = px.id
WHERE
	pi.created >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR) 

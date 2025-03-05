SELECT 
	pi.region,
	pi.id AS payment_intent_id
FROM all_stripe.payment_intent AS pi
WHERE
	pi.created >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR) 

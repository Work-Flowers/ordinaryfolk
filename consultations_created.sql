SELECT
	checkout.country,
	DATE(t.`timestamp`) AS date,
	COUNT(DISTINCT checkout.order_id) AS n_consultations_created
FROM segment.checkout_completed AS checkout
INNER JOIN segment.tracks AS t
	ON checkout.message_id = t.message_id
INNER JOIN segment.checkout_completed_products AS prod
	ON checkout.message_id = prod.message_id
	AND prod.condition = 'teleconsultation'
GROUP BY 1,2
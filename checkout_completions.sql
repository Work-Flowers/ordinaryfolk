WITH consultations_created AS(
	SELECT
		checkout.country,
		DATE(t.`timestamp`) AS date,
		COUNT(DISTINCT checkout.order_id) AS n
	FROM segment.checkout_completed AS checkout
	INNER JOIN segment.tracks AS t
		ON checkout.message_id = t.message_id
	INNER JOIN segment.checkout_completed_products AS prod
		ON checkout.message_id = prod.message_id
		AND prod.condition = 'teleconsultation'
	GROUP BY 1,2
),

scheduled AS (
	SELECT
		DATE(t.`timestamp`) AS date,
		seg.country,
		COUNT(DISTINCT seg.order_id) AS n
	FROM segment.order_completed AS seg
	INNER JOIN all_postgres.order AS o
		ON seg.order_id = o.sys_id
  		AND o.status = 'pending_prescription'
	INNER JOIN segment.tracks AS t
		ON seg.message_id = t.message_id
	GROUP BY 1,2
)

SELECT
	cc.date,
	cc.country,
	cc.n AS n_consultations_created,
	scheduled.n AS consultations_scheduled
	
FROM consultations_created AS cc
FULL OUTER JOIN scheduled
	ON cc.date = scheduled.date
	AND cc.country = scheduled.country	



WITH first_session AS (
	SELECT
		c.sys_id,
		o.patient_id
	FROM all_postgres.consultation_sessions AS c
	INNER JOIN all_postgres.order AS o
		ON c.order_sys_id = o.sys_id
	QUALIFY ROW_NUMBER() OVER (PARTITION BY o.patient_id ORDER BY c.created_at) = 1
)


SELECT
	cs.region,
	DATE(cs.created_at) AS date,
	cs.sys_id AS consult_sys_id,
	o.short_id AS order_short_id,
	cs.consultation_session_type,
	cs.consultation_session_status,
	cs.progress_status,
	CASE 
		WHEN fs.sys_id IS NOT NULL THEN 'New'
		ELSE 'Follow-up'
		END AS new_follow_up,
	JSON_VALUE(prod.metadata, '$.condition') AS condition
FROM all_postgres.consultation_sessions AS cs
INNER JOIN all_postgres.order AS o
	ON cs.order_sys_id = o.sys_id
LEFT JOIN all_stripe.price AS px
	ON COALESCE(o.prescription_price_id, o.price_id) = px.id
LEFT JOIN all_stripe.product AS prod
	ON px.product_id = prod.id
LEFT JOIN first_session AS fs
	ON cs.sys_id = fs.sys_id
-- ORDER BY 2 DESC
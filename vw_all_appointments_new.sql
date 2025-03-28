SELECT
	cs.region,
	DATE(cs.created_at) AS date,
	cs.sys_id AS consult_sys_id,
	o.short_id AS order_short_id,
	cs.consultation_session_type,
	cs.consultation_session_status,
	cs.progress_status,
	ca.consult_type,
	ca.status AS audit_status,
	ca.evaluation_id AS audit_evaluation_id,
	JSON_VALUE(prod.metadata, '$.condition') AS order_product_condition
FROM all_postgres.consultation_sessions AS cs
INNER JOIN all_postgres.order AS o
	ON cs.order_sys_id = o.sys_id
LEFT JOIN all_stripe.price AS px
	ON COALESCE(o.prescription_price_id, o.price_id) = px.id
LEFT JOIN all_stripe.product AS prod
	ON px.product_id = prod.id
LEFT JOIN all_postgres.consultation_audit AS ca
	ON cs.consultationauditsysid = ca.sys_id

-- ORDER BY 2 DESC
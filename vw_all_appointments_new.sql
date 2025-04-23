SELECT
	cs.region,
	DATE(cs.created_at) AS date,
	cs.sys_id AS consult_sys_id,
	cs.consultation_session_type,
	o.short_id AS order_short_id,
	cs.order_sys_id,
	cs.consultation_session_status,
	cs.progress_status,
	ca.consult_type,
	ca.status AS audit_status,
	ca.evaluation_id AS audit_evaluation_id,
	cmap.stripe_condition AS condition,
	o.status AS order_status,
	o.prescription_id IS NOT NULL AS has_prescription,
	o.stripe_subscription_id IS NOT NULL AS has_subscription,
	COALESCE(utm.channel, JSON_VALUE(o.utm, '$.utmSource')) AS utm_source,
FROM all_postgres.consultation_sessions AS cs
LEFT JOIN all_postgres.order AS o
	ON cs.order_sys_id = o.sys_id
LEFT JOIN all_postgres.consultation_audit AS ca
	ON cs.consultationauditsysid = ca.sys_id
LEFT JOIN google_sheets.postgres_stripe_condition_map AS cmap
	ON ca.evaluation_id = cmap.postgres_condition
LEFT JOIN cac.utm_source_map AS utm
	ON JSON_VALUE(o.utm, '$.utmSource') = utm.context_campaign_source
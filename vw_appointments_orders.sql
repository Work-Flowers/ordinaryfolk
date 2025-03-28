DROP VIEW IF EXISTS all_postgres.all_appointments;
CREATE VIEW all_postgres.all_appointments AS 

WITH first_appt AS (
	SELECT *
	FROM all_postgres.acuity_appointment_latest
	-- only include the first appointment for each customer
	QUALIFY ROW_NUMBER() OVER (PARTITION BY email ORDER BY date) = 1
),

first_text_consult AS (
	SELECT 
		txt.region,
		txt.message_id,
		t.timestamp,
		t.context_campaign_source,
		txt.condition,
		txt.order_id
	FROM segment.text_consultation_booked AS txt
	INNER JOIN segment.tracks AS t
		ON txt.message_id = t.message_id
	-- only include the first appointment for each customer
	QUALIFY ROW_NUMBER() OVER (PARTITION BY t.user_id ORDER BY t.timestamp) = 1
)

SELECT
	'Acuity' AS source,
	appt.region,
	CAST(appt.sys_id AS STRING) AS id,
	DATE(appt.created_at) AS date,
	appt.canceled,
	appt.no_show,
	o.sys_id AS ordersysid,
	o.status,
	o.prescription_id IS NOT NULL AS has_prescription,
	o.stripe_subscription_id IS NOT NULL AS has_subscription,
	COALESCE(utm.channel, JSON_VALUE(o.utm, '$.utmSource')) AS utm_source,
	atc.condition
FROM first_appt AS appt
LEFT JOIN all_postgres.order_acuity_appointment AS map
	ON appt.sys_id = map.acuityappointmentsysid
LEFT JOIN all_postgres.order AS o
	ON map.ordersysid = o.sys_id
LEFT JOIN google_sheets.acuity_type_condition_map AS atc
	ON appt.type = atc.type
LEFT JOIN cac.utm_source_map AS utm
	ON JSON_VALUE(o.utm, '$.utmSource') = utm.context_campaign_source



UNION ALL

SELECT
	'HK Text Consult' AS source,
	txt.region,
	txt.message_id AS id,
	DATE(txt.timestamp) AS date,
	FALSE AS canceled,
	FALSE AS no_show,
	txt.order_id AS ordersysid,
	o.status,
	o.prescription_id IS NOT NULL AS has_prescription,
	o.stripe_subscription_id IS NOT NULL AS has_subscription,
	COALESCE(utm.channel, txt.context_campaign_source) AS utm_source,
	map.stripe_condition AS condition
FROM first_text_consult AS txt
LEFT JOIN all_postgres.order AS o
	ON txt.order_id = o.sys_id
LEFT JOIN google_sheets.postgres_stripe_condition_map AS map
	ON txt.condition = map.postgres_condition
LEFT JOIN cac.utm_source_map AS utm
	ON txt.context_campaign_source = utm.context_campaign_source


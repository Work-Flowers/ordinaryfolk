DROP VIEW IF EXISTS all_postgres.all_appointments;
CREATE VIEW all_postgres.all_appointments AS 

SELECT
	'Acuity' AS source,
	appt.region,
	CAST(appt.sys_id AS STRING) AS id,
	DATE(appt.date) AS date,
	appt.canceled,
	appt.no_show,
	o.status,
	o.prescription_id IS NOT NULL AS has_prescription,
	JSON_VALUE(o.utm, '$.utmSource') AS utm_source,
	JSON_VALUE(prod.metadata, '$.condition') AS condition
FROM all_postgres.acuity_appointment_latest AS appt
LEFT JOIN all_postgres.order_acuity_appointment AS map
	ON appt.sys_id = map.acuityappointmentsysid
LEFT JOIN all_postgres.order AS o
	ON map.ordersysid = o.sys_id
LEFT JOIN all_stripe.price AS px
	ON COALESCE(o.prescription_price_id, o.price_id) = px.id
LEFT JOIN all_stripe.product AS prod
	ON px.product_id = prod.id	
-- WHERE DATE(appt.date) <= CURRENT_DATE
-- only include the first appointment for each customer
QUALIFY ROW_NUMBER() OVER (PARTITION BY appt.email ORDER BY appt.date) = 1

UNION ALL

SELECT
	'HK Text Consult' AS source,
	txt.region,
	txt.message_id AS id,
	DATE(t.timestamp) AS date,
	FALSE AS canceled,
	FALSE AS no_show,
	CAST(NULL AS STRING) AS status,
	FALSE AS has_prescription,
	t.context_campaign_source AS utm_source,
	map.stripe_condition AS condition
FROM segment.text_consultation_booked AS txt
INNER JOIN segment.tracks AS t
	ON txt.message_id = t.message_id
LEFT JOIN google_sheets.postgres_stripe_condition_map AS map
	ON txt.condition = map.postgres_condition
-- only include the first appointment for each customer
QUALIFY ROW_NUMBER() OVER (PARTITION BY t.user_id ORDER BY t.timestamp) = 1
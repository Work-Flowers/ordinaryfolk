SELECT
	appt.region,
	appt.id,
	appt.date,
	appt.canceled,
	appt.no_show,
	o.status,
	o.prescription_id IS NOT NULL AS has_prescription
FROM all_postgres.acuity_appointment_latest AS appt
LEFT JOIN all_postgres.order_acuity_appointment AS map
	ON appt.sys_id = map.acuityappointmentsysid
LEFT JOIN all_postgres.order AS o
	ON map.ordersysid = o.sys_id
WHERE DATE(appt.date) <= CURRENT_DATE

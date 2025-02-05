WITH attendance AS (
	SELECT
		t1.user_id,
		t1.message_id,
		att.attendance
	FROM segment.tracks AS t1
	INNER JOIN segment.patient_check_in_consultation_attendance AS att
		ON t1.message_id = att.message_id
)

SELECT
	DATE(
		PARSE_DATETIME('%d-%m-%Y %I:%M%p', tor.schedule_date)
	) AS appt_date,
	t.user_id,
	attendance.attendance
FROM segment.automatically_booked_follow_up_consult AS tor
LEFT JOIN segment.tracks AS t
	ON tor.message_id = t.message_id
LEFT JOIN attendance
	ON t.user_id = attendance.user_id
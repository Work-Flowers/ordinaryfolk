SELECT 
	a.*

FROM all_postgres.all_appointments AS a
WHERE 
	1 = 1 
	AND a.has_subscription IS FALSE
	-- only pull from last three months
	AND a.date >= DATE_SUB(CURRENT_DATE, INTERVAL 3 MONTH)
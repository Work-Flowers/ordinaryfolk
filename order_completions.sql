SELECT
	DATE(o.created_at) AS date,
	o.country,
	COUNT(DISTINCT o.sys_id) AS n_orders,
	COUNT(DISTINCT comp.order_id) AS n_completed
FROM all_postgres.order AS o
LEFT JOIN segment.order_completed AS comp
	ON o.sys_id = comp.order_id
GROUP BY 1,2

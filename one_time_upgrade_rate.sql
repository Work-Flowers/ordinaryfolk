WITH one_time AS (
	
	SELECT
		ch.customer_id,
		MIN(DATE(ch.created)) AS acq_date
	FROM all_stripe.charge AS ch
	LEFT JOIN all_stripe.invoice AS inv
		ON ch.invoice_id = inv.id
	WHERE 
		ch.status = 'succeeded'
		AND inv.subscription_id IS NULL
	GROUP BY 1	
),

subscribers AS (
	SELECT
		ch.customer_id,
		MIN(DATE(ch.created)) AS acq_date
	FROM all_stripe.charge AS ch
	INNER JOIN all_stripe.invoice AS inv
		ON ch.invoice_id = inv.id
		AND inv.subscription_id IS NOT NULL
	WHERE 
		ch.status = 'succeeded'	
	GROUP BY 1	

)

SELECT
	s.acq_date IS NOT NULL AS subscribed,
	COUNT(DISTINCT o.customer_id) AS n_customers,
	COUNT(DISTINCT o.customer_id) / SUM(COUNT(DISTINCT o.customer_id)) OVER() AS share
FROM one_time AS o
LEFT JOIN subscribers AS s
	ON o.customer_id = s.customer_id
	AND s.acq_date > o.acq_date
GROUP BY 1
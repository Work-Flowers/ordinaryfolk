WITH intervals AS (
	SELECT DISTINCT
		UPPER(sh.region) AS country,
		sh.id AS subscription_id,
		DATE(sh.created) AS subscription_created,
		DATE(sh._fivetran_start) AS subscription_updated,
		p.id AS plan_id,
		p.product_id,
		prod.name AS product_name,
		JSON_EXTRACT_SCALAR(prod.metadata, '$.condition') AS condition,
		i.created AS invoice_date,
		p.interval_count AS current_interval_count,
		LAG(p.interval_count) OVER (
			PARTITION BY sh.id, p.product_id
			ORDER BY sh._fivetran_start
		) AS previous_interval_count,
	    FIRST_VALUE(p.interval_count) OVER (
	        PARTITION BY sh.id, p.product_id
	        ORDER BY sh._fivetran_start
	    ) AS first_interval_count
	FROM all_stripe.subscription_history AS sh
	JOIN all_stripe.invoice AS i 
		ON sh.latest_invoice_id = i.id
	JOIN all_stripe.invoice_line_item AS ili 
		ON i.id = ili.invoice_id
	JOIN all_stripe.plan AS p 
		ON ili.plan_id = p.id
		AND p.interval = 'month'
	JOIN all_stripe.product AS prod
		ON p.product_id = prod.id
)

SELECT 
	intervals.*,
	DATE_DIFF(subscription_updated, subscription_created, DAY) AS days_elapsed	
FROM intervals
WHERE 
	1 = 1
	AND first_interval_count <= 3
	AND current_interval_count > previous_interval_count
	AND current_interval_count > 3
	AND DATE_DIFF(subscription_updated, subscription_created, DAY)  <= 90

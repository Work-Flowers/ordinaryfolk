WITH all_intervals AS (
	SELECT DISTINCT
		UPPER(sh.region) AS country,
		sh.id AS subscription_id,
		sh.status,
		DATE(sh.created) AS subscription_created,
		DATE(sh._fivetran_start) AS subscription_updated,
		p.id AS plan_id,
		p.product_id,
		prod.name AS product_name,
		JSON_EXTRACT_SCALAR(prod.metadata, '$.condition') AS condition,
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
	JOIN all_stripe.invoice_line_item AS ili 
		ON sh.latest_invoice_id = ili.invoice_id
	JOIN all_stripe.plan AS p 
		ON ili.plan_id = p.id
		AND p.interval = 'month'
	JOIN all_stripe.product AS prod
		ON p.product_id = prod.id
),

first_interval AS (
	SELECT *
	FROM all_intervals
	WHERE
		1 = 1 
		AND first_interval_count <= 3
		AND status = 'active'
	QUALIFY ROW_NUMBER() OVER (
		PARTITION BY subscription_id, product_id
		ORDER BY subscription_updated
	) = 1
)

SELECT 
	fi.country,
	fi.subscription_id,
	fi.subscription_created,
	ai.subscription_updated,
	fi.plan_id, 
	fi.product_id,
	fi.product_name,
	fi.condition,
	fi.first_interval_count,
	ai.current_interval_count,
	DATE_DIFF(ai.subscription_updated, ai.subscription_created, DAY) AS days_elapsed	
FROM first_interval AS fi
LEFT JOIN all_intervals AS ai
	ON fi.subscription_id = ai.subscription_id
	AND fi.product_id = ai.product_id
	AND ai.current_interval_count > ai.previous_interval_count
	AND ai.current_interval_count > 3
	AND DATE_DIFF(ai.subscription_updated, ai.subscription_created, DAY)  <= 90
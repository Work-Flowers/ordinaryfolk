DROP VIEW IF EXISTS cac.marketing_cost_per_action;
CREATE VIEW cac.marketing_cost_per_action AS

WITH signups AS (
    SELECT
        DATE(t.timestamp) AS date,
        LOWER(s.country) AS country,
        map.channel,
        COUNT(s.message_id) AS n
    FROM segment.signed_up AS s
    INNER JOIN segment.tracks AS t ON s.message_id = t.message_id
    INNER JOIN cac.utm_source_map AS map 
    	ON s.utm_source = map.context_campaign_source
    GROUP BY 1, 2, 3
),

q3_completions AS (
    SELECT
        DATE(t.timestamp) AS date,
        LOWER(v.country) AS country,
        map.channel,
        COUNT(v.message_id) AS n
    FROM segment.viewed_4_th_question_of_eval AS v
    INNER JOIN segment.tracks AS t ON v.message_id = t.message_id
    LEFT JOIN cac.utm_source_map AS map 
    	ON v.utm_source = map.context_campaign_source
    GROUP BY 1, 2, 3
),

checkouts AS (
    SELECT
        DATE(t.timestamp) AS date,
        LOWER(c.country) AS country,
        map.channel,
        COUNT(c.message_id) AS n
    FROM segment.checkout_completed AS c
    INNER JOIN segment.tracks AS t ON c.message_id = t.message_id
    INNER JOIN cac.utm_source_map AS map 
    	ON c.utm_source = map.context_campaign_source
    GROUP BY 1, 2, 3
),

marketing_spend AS (
    SELECT
        date,
        LOWER(country_code) AS country,
        channel,
        cost_usd
    FROM cac.marketing_spend
),

consults AS (
	SELECT
		DATE(appt.date) AS date,
		appt.region AS country,
		map.channel,
		COUNT(DISTINCT appt.sys_id) AS n
	FROM all_postgres.acuity_appointment_latest AS appt
	LEFT JOIN all_postgres.order_acuity_appointment AS oaa
		ON appt.sys_id = oaa.acuityappointmentsysid
	LEFT JOIN all_postgres.order AS o
		ON oaa.ordersysid = o.sys_id
	LEFT JOIN cac.utm_source_map AS map
		ON JSON_EXTRACT_SCALAR(o.utm, '$.utmSource') = map.context_campaign_source
	GROUP BY 1,2,3
),

customer_history AS (
	
	SELECT
		cm.customer_id,
		cm.purchase_date AS first_purchase_date,
		cm.charge_id,
		cm.product_name AS first_product,
		LEAD(cm.product_name, 1) OVER(PARTITION BY customer_id ORDER BY purchase_date) AS second_product,
		COALESCE(cm.line_item_amount_usd, cm.total_charge_amount_usd) AS first_revenue,
		LEAD(COALESCE(cm.line_item_amount_usd, cm.total_charge_amount_usd), 1) OVER (PARTITION BY customer_id ORDER BY purchase_date) AS second_revenue,
		ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY purchase_date) AS row
		 
	FROM finance_metrics.contribution_margin AS cm
	LEFT JOIN all_postgres.order AS o
		ON cm.pay
	WHERE cm.customer_id IS NOT NULL
	QUALIFY ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY purchase_date) <= 2
	ORDER BY 1,2
)
-- Step 1: Create a superset of all (date, country, channel) combinations
all_keys AS (
    
    SELECT DISTINCT 
    	date, 
    	country, 
    	channel 
	FROM signups
    
    UNION DISTINCT
    
    SELECT DISTINCT 
    	date, 
    	country, 
    	channel 
	FROM q3_completions
    
    UNION DISTINCT
    
    SELECT DISTINCT 
    	date, 
    	country, 
    	channel 
	FROM checkouts
    
    UNION DISTINCT
    
    SELECT DISTINCT 
    	date, 
    	country, 
    	channel 
	FROM marketing_spend
	
	UNION DISTINCT
	
	SELECT DISTINCT 
    	date, 
    	country, 
    	channel 
	FROM consults
	
)

-- Step 2: Perform FULL OUTER JOINS using the superset as the base
SELECT
    k.date,
    k.country,
    k.channel,
    COALESCE(ms.cost_usd, 0) AS cost_usd,
    COALESCE(sup.n, 0) AS n_signups,
    COALESCE(q.n, 0) AS n_q3_completions,
    COALESCE(cc.n, 0) AS n_checkouts_completed,
    COALESCE(cons.n, 0) AS n_consults
FROM all_keys k
LEFT JOIN marketing_spend AS ms
    ON k.date = ms.date 
    AND k.country = ms.country 
    AND k.channel = ms.channel
LEFT JOIN signups AS sup
    ON k.date = sup.date 
    AND k.country = sup.country 
    AND k.channel = sup.channel
LEFT JOIN q3_completions AS q
    ON k.date = q.date 
    AND k.country = q.country 
    AND k.channel = q.channel
LEFT JOIN checkouts AS cc
    ON k.date = cc.date 
    AND k.country = cc.country 
    AND k.channel = cc.channel
LEFT JOIN consults AS cons
    ON k.date = cons.date 
    AND k.country = cons.country 
    AND k.channel = cons.channel
WHERE 
	k.date >= '2025-01-27'
	AND k.country IS NOT NULL;
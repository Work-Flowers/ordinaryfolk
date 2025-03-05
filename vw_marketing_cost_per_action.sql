DROP VIEW IF EXISTS cac.marketing_cost_per_action;
CREATE VIEW cac.marketing_cost_per_action AS

WITH signups AS (
	SELECT
		DATE(t.timestamp) AS date,
		s.country,
		map.channel,
		COUNT(s.message_id) AS n
	FROM segment.signed_up AS s
	INNER JOIN segment.tracks AS t
		ON s.message_id = t.message_id
	INNER JOIN cac.utm_source_map AS map
		ON s.utm_source = map.context_campaign_source
	GROUP BY 1,2,3
),

q3_completions AS (
    SELECT
    	DATE(t.timestamp) AS date,
    	v.country,
    	map.channel,
    	COUNT(v.message_id) AS n
    FROM segment.viewed_4_th_question_of_eval AS v
    INNER JOIN segment.tracks AS t
		ON v.message_id = t.message_id
	INNER JOIN cac.utm_source_map AS map
		ON v.utm_source = map.context_campaign_source
	GROUP BY 1,2,3
),

checkouts AS (
    SELECT
    	DATE(t.timestamp) AS date,
    	c.country,
    	map.channel,
    	COUNT(c.message_id) AS n
    FROM segment.checkout_completed AS c
    INNER JOIN segment.tracks AS t
		ON c.message_id = t.message_id
	INNER JOIN cac.utm_source_map AS map
		ON c.utm_source = map.context_campaign_source
	GROUP BY 1,2,3

)

SELECT
	ms.channel,
	LOWER(ms.country_code) AS country,
	ms.date,
	ms.cost_usd,
	sup.n AS n_signups,
	q.n AS n_q3_completions,
	cc.n AS n_checkouts_completed
FROM cac.marketing_spend AS ms
LEFT JOIN signups AS sup
	ON ms.date = sup.date
	AND ms.channel = sup.channel
	AND LOWER(ms.country_code) = sup.country	
LEFT JOIN q3_completions AS q
	ON ms.date = q.date
	AND ms.channel = q.channel
	AND LOWER(ms.country_code) = q.country	
LEFT JOIN checkouts AS cc
	ON ms.date = cc.date
	AND ms.channel = cc.channel
	AND LOWER(ms.country_code) = cc.country		
WHERE
	ms.date >= '2025-01-27' -- date we began syncing Segment data into BigQuery

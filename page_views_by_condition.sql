WITH all_views AS (
	SELECT
		DATE(p.`timestamp`) AS date,
		p.region,
		COALESCE(JSON_EXTRACT_SCALAR(str.metadata, '$.condition'), map.stripe_condition) AS condition,
		COUNT(DISTINCT p.message_id) AS page_views
	FROM segment.pages AS p
	LEFT JOIN all_stripe.product AS str
		ON p.product_id = str.id
	LEFT JOIN ref.segment_condition_to_stripe_condition AS map
		ON REGEXP_EXTRACT(p.name, r'Health Profile - ([^-]+) -') = map.segment_condition
	WHERE
		COALESCE(JSON_EXTRACT_SCALAR(str.metadata, '$.condition'), map.stripe_condition) IS NOT NULL
	GROUP BY 1,2,3
),

q4_views AS (
	SELECT
		DATE(t.`timestamp`) AS date,
		v.region,
		map.stripe_condition AS condition,
		COUNT(DISTINCT v.message_id) AS q4_views
	FROM segment.viewed_4_th_question_of_eval AS v
	INNER JOIN segment.tracks AS t
		ON v.message_id = t.message_id
	LEFT JOIN ref.segment_condition_to_stripe_condition AS map
		ON v.evaluation_type = map.segment_condition
	GROUP BY 1,2,3
)


SELECT
	av.date,
	av.region,
	av.condition,
	av.page_views AS total_views,
	q.q4_views
FROM all_views AS av
LEFT JOIN q4_views AS q
	ON av.date = q.date
	AND av.region = q.region
	AND av.condition = q.condition

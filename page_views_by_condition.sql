SELECT
	DATE(p.`timestamp`) AS date,
	COALESCE(JSON_EXTRACT_SCALAR(str.metadata, '$.condition'), map.stripe_condition) AS condition,
	COUNT(DISTINCT p.message_id) AS page_views
FROM segment.pages AS p
LEFT JOIN all_stripe.product AS str
	ON p.product_id = str.id
LEFT JOIN ref.segment_condition_to_stripe_condition AS map
	ON REGEXP_EXTRACT(p.name, r'Health Profile - ([^-]+) -') = map.segment_condition
WHERE
	COALESCE(JSON_EXTRACT_SCALAR(str.metadata, '$.condition'), map.stripe_condition) IS NOT NULL
GROUP BY 1,2
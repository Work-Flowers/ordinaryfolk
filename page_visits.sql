SELECT
	DATE(timestamp) AS date,
	category,
	UPPER(region) AS country,
	product,
	platform,
	CASE 
		WHEN context_campaign_source LIKE '%google%' THEN 'Google'
		WHEN context_campaign_source LIKE '%facebook%' THEN 'Facebook'
		WHEN context_campaign_source LIKE '%webflow%' THEN 'Webflow'
		WHEN context_campaign_source LIKE '%customer.io%' THEN 'customer.io'
		WHEN context_campaign_source LIKE '%bing%' THEN 'Bing'
		WHEN context_campaign_source LIKE '%taboola%' THEN 'Taboola'
		WHEN context_campaign_source LIKE '%ig%' THEN 'Instagram'
		ELSE context_campaign_source 
		END AS campaign_source,
	CASE 
		WHEN context_campaign_medium LIKE '%cpc%' THEN 'CPC'
		WHEN context_campaign_medium LIKE '%email%' THEN 'Email'
		WHEN context_campaign_medium LIKE '%native%' THEN 'Native'
		WHEN context_campaign_medium LIKE '%bio%' THEN 'Bio'
		ELSE context_campaign_medium 
		END AS campaign_medium,
	user_id
FROM `noah-e30be.segment.pages`
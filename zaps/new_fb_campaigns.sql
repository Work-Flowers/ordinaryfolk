

SELECT DISTINCT
	ms.campaign_name
FROM cac.marketing_spend AS ms
LEFT JOIN google_sheets.campaign_condition_map AS cmap
	ON LOWER(ms.campaign_name) = LOWER(cmap.campaign_name)
	AND ms.channel = cmap.channel 
WHERE 
	ms.channel = 'facebook_ads'
	AND cmap.campaign_name IS NULL
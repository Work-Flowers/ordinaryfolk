DROP VIEW IF EXISTS cac.utm_source_map;
CREATE VIEW cac.utm_source_map AS

SELECT DISTINCT
	CASE
		WHEN LOWER(context_campaign_source) LIKE 'facebook%' THEN 'facebook_ads'
    	WHEN LOWER(context_campaign_source) LIKE 'fb%' THEN 'facebook_ads'
		WHEN LOWER(context_campaign_source) LIKE 'ig%' THEN 'facebook_ads'
    	WHEN LOWER(context_campaign_source) LIKE 'google%' THEN 'google_ads'
    	WHEN LOWER(context_campaign_source) LIKE 'youtube%' THEN 'google_ads'
    	WHEN LOWER(context_campaign_source) LIKE 'webflow%' THEN 'webflow_ads'
    	WHEN LOWER(context_campaign_source) LIKE 'bing%' THEN 'bing'
    	WHEN LOWER(context_campaign_source) LIKE 'customer.io%' THEN 'customer.io'
    	WHEN LOWER(context_campaign_source) LIKE 'taboola%' THEN 'taboola'
    	WHEN LOWER(context_campaign_source) LIKE 'chatgpt%' THEN 'chatgpt'
    	WHEN LOWER(context_campaign_source) LIKE 'menarini%' THEN 'menarini'
    	WHEN LOWER(context_campaign_source) LIKE 'edm%' THEN 'edm'
    	WHEN LOWER(context_campaign_source) LIKE 'klaviyo%' THEN 'klaviyo'
    	WHEN LOWER(context_campaign_source) LIKE 'perplexity%' THEN 'perplexity'
    	WHEN LOWER(context_campaign_source) LIKE 'pornhub%' THEN 'pornhub'
    	WHEN LOWER(context_campaign_source) LIKE 'msg%' THEN 'msg'
    	
    	WHEN LOWER(context_campaign_source) LIKE 'hk01%' THEN 'hk01'
    	ELSE context_campaign_source
    	END AS channel
FROM segment.pages
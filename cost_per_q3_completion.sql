WITH campaigns AS (
	SELECT DISTINCT
		id,
		name
	FROM google_ads.campaign_history
),

ga_account_currency AS (
	SELECT
		id AS account_id,
		currency_code
	FROM google_ads.account_history
	QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY updated_at DESC) = 1
),

fb_account_currency AS (
	SELECT
		id AS account_id,
		currency
    FROM facebook_ads.account_history
	QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY created_time DESC) = 1
),

seg AS (
	SELECT
		REGEXP_REPLACE(SPLIT(utm_campaign, ',')[OFFSET(0)], r'_[0-9]+$', '') AS utm_campaign,
	    CASE 
	    	WHEN utm_source LIKE 'facebook%' THEN 'Facebook'
	    	WHEN utm_source LIKE 'fb%' THEN 'Facebook'
	    	WHEN utm_source LIKE 'google%' THEN 'Google'
	    	WHEN utm_source LIKE 'webflow%' THEN 'Webflow'
	    	WHEN utm_source LIKE 'ig%' THEN 'Instagram'
	    	WHEN utm_source LIKE 'bing%' THEN 'Bing'
	    	WHEN utm_source LIKE 'customer.io%' THEN 'customer.io'
	    	WHEN utm_source LIKE 'taboola%' THEN 'Taboola'
	    	WHEN utm_source LIKE 'chatgpt%' THEN 'ChatGPT'
	    	ELSE utm_source
	    	END AS utm_source,
		DATE(t.`timestamp`) AS date,
	    COUNT(DISTINCT views.message_id) AS completions
    FROM segment.viewed_4_th_question_of_eval AS views
    LEFT JOIN segment.tracks AS t
		ON views.message_id = t.message_id
	GROUP BY 1,2,3
),

all_traffic AS (
	SELECT
		DATE(p.`timestamp`) AS date,
		CASE 
	    	WHEN context_campaign_source LIKE 'facebook%' THEN 'Facebook'
	    	WHEN context_campaign_source LIKE 'fb%' THEN 'Facebook'
	    	WHEN context_campaign_source LIKE 'google%' THEN 'Google'
	    	WHEN context_campaign_source LIKE 'webflow%' THEN 'Webflow'
	    	WHEN context_campaign_source LIKE 'ig%' THEN 'Instagram'
	    	WHEN context_campaign_source LIKE 'bing%' THEN 'Bing'
	    	WHEN context_campaign_source LIKE 'customer.io%' THEN 'customer.io'
	    	WHEN context_campaign_source LIKE 'taboola%' THEN 'Taboola'
	    	WHEN context_campaign_source LIKE 'chatgpt%' THEN 'ChatGPT'
	    	ELSE context_campaign_source
	    	END AS utm_source,
		COUNT(message_id) AS page_visits
	FROM segment.pages AS p
	GROUP BY 1,2
)

SELECT DISTINCT
    seg.utm_campaign,
    seg.utm_source,
    seg.date,
    seg.completions,
    all_traffic.page_visits,
    SUM(COALESCE(fb.spend, cs.cost_micros / 1e6) / fx.fx_to_usd) AS spend_usd 
FROM seg
LEFT JOIN all_traffic
	ON seg.utm_source = all_traffic.utm_source
	AND seg.date  = all_traffic.date
LEFT JOIN facebook_ads.basic_campaign AS fb
	ON seg.utm_campaign = fb.campaign_name
	AND seg.date = fb.`date`
LEFT JOIN fb_account_currency AS fbfx
	ON fb.account_id = fbfx.account_id
LEFT JOIN campaigns AS ga
	ON seg.utm_campaign = ga.name
LEFT JOIN google_ads.campaign_stats AS cs
	ON ga.id = cs.id
	AND seg.date = cs.`date`
LEFT JOIN ga_account_currency AS gafx
	ON cs.customer_id = gafx.account_id
LEFT JOIN ref.fx_rates AS fx
	ON LOWER(COALESCE(fbfx.currency, gafx.currency_code)) = fx.currency
GROUP BY 1,2,3,4,5
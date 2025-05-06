
-- CTEs for Google
WITH ga_targeting AS (
	SELECT
		campaign_id,
		geo_target_constant_id
	FROM google_ads.campaign_criterion_history
	WHERE 
		geo_target_constant_id IS NOT NULL
	QUALIFY ROW_NUMBER() OVER (PARTITION BY campaign_id ORDER BY updated_at DESC) = 1
),

ga_account_currency AS (
	SELECT
		id AS customer_id,
		currency_code
	FROM google_ads.account_history
	QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY updated_at DESC) = 1
),

google_campaigns AS (
	SELECT
		ch.id,
		ch.name
	FROM google_ads.campaign_history AS ch
	QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY ch.updated_at DESC) = 1
),

google_ad_history AS (
	SELECT *
	FROM google_ads.ad_history
	QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY updated_at DESC) = 1
),

google_roas AS (
	SELECT
		a.date,
		LOWER(g.country_code) AS country,
		LOWER(gac.currency_code) AS currency,
		CAST(a.ad_id AS STRING) AS ad_id,
		google_campaigns.name AS campaign_name,
		SUM(a.impressions) AS impressions,
		SUM(a.clicks) AS clicks,
		SUM(a.cost_micros / 1e6) AS cost_local,
		SUM(a.conversions_value) AS purchases_local
	FROM google_ads.ad_stats AS a
	LEFT JOIN google_campaigns
		ON a.campaign_id = google_campaigns.id
	LEFT JOIN ga_targeting
		ON a.campaign_id = ga_targeting.campaign_id
	LEFT JOIN google_ads.geo_target AS g
		ON ga_targeting.geo_target_constant_id = g.id
	LEFT JOIN ga_account_currency AS gac
		ON a.customer_id = gac.customer_id
	WHERE 
		1 = 1
	GROUP BY 1,2,3,4,5
),

-- CTEs for Facebook

fb_account_currency AS (
	SELECT
		CAST(id AS STRING) AS account_id,
		currency
    FROM facebook_ads.account_history
	QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY created_time DESC) = 1
),

fb_ash AS (
	SELECT *
	FROM facebook_ads.ad_set_history
	QUALIFY ROW_NUMBER() OVER(PARTITION BY id ORDER BY updated_time DESC) = 1
),

fb_ad_history AS (
	SELECT *
	FROM facebook_ads.ad_history
	QUALIFY ROW_NUMBER() OVER(PARTITION BY id ORDER BY updated_time DESC) = 1

),

fb_core AS (
	SELECT
		d.date,
		d.ad_id,
		d.campaign_name,
		LOWER(a.currency) AS currency,
	    LOWER(REGEXP_REPLACE(ash.targeting_geo_locations_countries, r'[\[\]"]', '')) AS country,
		SUM(d.ctr * d.impressions / 100) AS clicks,
		SUM(d.impressions) AS impressions,
		SUM(d.spend) AS cost_local
	FROM facebook_ads.basic_all_levels AS d
	LEFT JOIN fb_ad_history
		ON CAST(d.ad_id AS STRING) = CAST(fb_ad_history.id AS STRING)
	LEFT JOIN fb_ash AS ash
	    ON CAST(fb_ad_history.ad_set_id AS STRING) = CAST(ash.id AS STRING)
	LEFT JOIN fb_account_currency AS a
		ON CAST(d.account_id AS STRING) = a.account_id
	LEFT JOIN ref.fx_rates AS fx
		ON LOWER(a.currency) = fx.currency
	WHERE
	    (d.reach > 0 OR d.ctr > 0 or d.spend > 0)
	GROUP BY 1,2,3,4,5
),

fb_roas AS (
	SELECT
		wpr.date,
		wpr.ad_id,
		wpr.value AS purchases_local
	FROM facebook_ads.delivery_purchase_roas_website_purchase_roas AS wpr

),

all_roas AS (
	
	SELECT 
		'google_ads' AS channel,
		google_roas.*
	FROM google_roas
	
	UNION ALL
	
	SELECT 
		'facebook_ads' AS channel,
		fb_core.date,
		fb_core.country,
		fb_core.currency,
		fb_core.ad_id,
		fb_core.campaign_name,
		fb_core.impressions,
		fb_core.clicks,
		fb_core.cost_local,
		fb_roas.purchases_local
	FROM fb_core 
	LEFT JOIN fb_roas
		ON fb_core.date = fb_roas.date
		AND fb_core.ad_id = fb_roas.ad_id
	
)

SELECT
	all_roas.*,
	ccm.condition,
	all_roas.cost_local / fx.fx_to_usd AS cost_usd,
	all_roas.purchases_local / fx.fx_to_usd AS purchases_usd,
FROM all_roas
LEFT JOIN ref.fx_rates AS fx
	ON all_roas.currency = fx.currency
LEFT JOIN google_sheets.campaign_condition_map AS ccm
	ON all_roas.campaign_name = ccm.campaign_name
-- Drop the existing view if it exists
DROP VIEW IF EXISTS `cac.marketing_spend`;

-- Create the view
CREATE VIEW `cac.marketing_spend` AS

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
		id AS account_id,
		currency_code
	FROM google_ads.account_history
	QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY updated_at DESC) = 1
),

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

google_campaigns AS (
	SELECT
		ch.id,
		ch.name
	FROM google_ads.campaign_history AS ch
	QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY ch.updated_at DESC) = 1
)

SELECT
	'google_ads' AS channel,
	s.date,
	google_campaigns.name AS campaign_name,
	ccm.`condition`,
	a.currency_code,
	g.country_code,
	NULL AS reach,
	SUM(s.clicks) AS clicks,
	SUM(s.impressions) AS impressions,
	-- Convert micros to standard currency
	SUM(s.cost_micros) / 1000000 AS cost_local, 	
	SUM(s.cost_micros / fx.fx_to_usd) / 1000000 AS cost_usd 
FROM google_ads.campaign_stats AS s
LEFT JOIN ga_targeting AS c
	ON s.id = c.campaign_id
LEFT JOIN google_campaigns
	ON s.id = google_campaigns.id
LEFT JOIN google_ads.geo_target AS g
	ON c.geo_target_constant_id = g.id
LEFT JOIN ga_account_currency AS a
	ON s.customer_id = a.account_id
LEFT JOIN ref.fx_rates AS fx
	ON LOWER(a.currency_code) = fx.currency
LEFT JOIN google_sheets.campaign_condition_map AS ccm
	ON google_campaigns.name = ccm.campaign_name
GROUP BY 1,2,3,4,5,6,7

UNION ALL

SELECT
	'facebook_ads' AS channel,
	d.date,
	d.campaign_name,
	ccm.condition,
	a.currency AS currency_code,
    REGEXP_REPLACE(ash.targeting_geo_locations_countries, r'[\[\]"]', '') AS country_code,
	SUM(d.reach) AS reach,
	SUM(d.ctr * d.impressions / 100) AS clicks,
	SUM(d.impressions) AS impressions,
	SUM(d.spend) AS cost_local,
	SUM(d.spend / fx.fx_to_usd) AS cost_usd
FROM facebook_ads.basic_ad_set AS d
LEFT JOIN fb_ash AS ash
    ON d.adset_id = CAST(ash.id AS STRING)
LEFT JOIN fb_account_currency AS a
	ON CAST(d.account_id AS STRING) = a.account_id
LEFT JOIN ref.fx_rates AS fx
	ON LOWER(a.currency) = fx.currency
LEFT JOIN google_sheets.campaign_condition_map AS ccm
	ON d.campaign_name = ccm.campaign_name
WHERE
    (d.reach > 0 OR d.ctr > 0 or d.spend > 0)
GROUP BY 1,2,3,4,5,6

UNION ALL

SELECT
	'taboola' AS channel,
	plat.date,
	tc.name AS campaign_name,
	ccm.condition,
	plat.currency AS currency_code,
	tgt.value AS country_code,
	SUM(0) AS reach,
	SUM(plat.clicks) AS clicks,
	SUM(plat.impressions) AS impressions,
	SUM(plat.spent) AS cost_local,
	SUM(plat.spent / fx.fx_to_usd) AS cost_usd
FROM taboola.platform_report AS plat
LEFT JOIN taboola.campaign AS tc
	ON plat.campaign_id = tc.id
LEFT JOIN taboola.targeting_country	AS tgt
	ON plat.campaign_id = tgt.campaign_id
LEFT JOIN ref.fx_rates AS fx
	ON LOWER(plat.currency) = LOWER(fx.currency)
LEFT JOIN google_sheets.campaign_condition_map AS ccm
	ON tc.name = ccm.campaign_name
GROUP BY 1,2,3,4,5,6
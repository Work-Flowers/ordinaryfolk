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
		g.country_code,
		a.ad_id,
		a.campaign_id,
		SUM(a.conversions) AS conversions,
		SUM(a.cost_micros / 1e6) AS cost_local,
		SUM(a.conversions_value) AS conversion_value,
	FROM google_ads.ad_stats AS a
	LEFT JOIN ga_targeting
		ON a.campaign_id = ga_targeting.campaign_id
	LEFT JOIN google_ads.geo_target AS g
		ON ga_targeting.geo_target_constant_id = g.id
	WHERE 
		1 = 1
	GROUP BY 1,2,3,4
)

SELECT * 
FROM google_roas
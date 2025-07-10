
WITH ga_targeting AS (
	SELECT
		campaign_id,
		geo_target_constant_id
	FROM google_ads.campaign_criterion_history
	WHERE 
		geo_target_constant_id IS NOT NULL
	QUALIFY ROW_NUMBER() OVER (PARTITION BY campaign_id ORDER BY updated_at DESC) = 1
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
)

SELECT DISTINCT
	google_campaigns.name,
	s.id
FROM google_ads.campaign_stats AS s
LEFT JOIN ga_targeting AS c
	ON s.id = c.campaign_id
LEFT JOIN google_campaigns
	ON s.id = google_campaigns.id
LEFT JOIN google_ads.geo_target AS g
	ON c.geo_target_constant_id = g.id
WHERE g.country_code IS NULL

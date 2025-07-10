WITH fb_ash AS (
	SELECT *
	FROM facebook_ads.ad_set_history
	QUALIFY ROW_NUMBER() OVER(PARTITION BY id ORDER BY updated_time DESC) = 1
),

fb_ad_history AS (
	SELECT *
	FROM facebook_ads.ad_history
	QUALIFY ROW_NUMBER() OVER(PARTITION BY id ORDER BY updated_time DESC) = 1

)

SELECT DISTINCT
	d.campaign_name,
	d.ad_id
FROM facebook_ads.basic_all_levels AS d
LEFT JOIN fb_ad_history
	ON CAST(d.ad_id AS STRING) = CAST(fb_ad_history.id AS STRING)
LEFT JOIN fb_ash AS ash
    ON CAST(fb_ad_history.ad_set_id AS STRING) = CAST(ash.id AS STRING)
WHERE
    (d.reach > 0 OR d.ctr > 0 or d.spend > 0)
    AND REGEXP_REPLACE(ash.targeting_geo_locations_countries, r'[\[\]"]', '') IS NULL

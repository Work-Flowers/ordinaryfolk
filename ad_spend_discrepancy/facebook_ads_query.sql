WITH fb_account_currency AS (
	SELECT
		CAST(id AS STRING) AS account_id,
		currency
    FROM facebook_ads.account_history
	QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY created_time DESC) = 1
)

SELECT
	'facebook_ads' AS channel,
	d.date,
	d.campaign_name,
	a.currency AS currency_code,
	SUM(d.reach) AS reach,
	SUM(d.ctr * d.impressions / 100) AS clicks,
	SUM(d.impressions) AS impressions,
	SUM(d.spend) AS cost_local
FROM facebook_ads.basic_ad AS d
LEFT JOIN fb_account_currency AS a
	ON CAST(d.account_id AS STRING) = a.account_id
LEFT JOIN ref.fx_rates AS fx
	ON LOWER(a.currency) = fx.currency
WHERE
    (d.reach > 0 OR d.ctr > 0 or d.spend > 0)
GROUP BY 1,2,3,4

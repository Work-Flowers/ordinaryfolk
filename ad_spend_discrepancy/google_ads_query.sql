WITH ga_account_currency AS (
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
)

SELECT
	s.date,
	google_campaigns.name AS campaign_name,
	a.currency_code,
	SUM(s.clicks) AS clicks,
	SUM(s.impressions) AS impressions,
	-- Convert micros to standard currency
	SUM(s.cost_micros) / 1000000 AS cost_local
FROM google_ads.campaign_stats AS s
LEFT JOIN google_campaigns
	ON s.id = google_campaigns.id
LEFT JOIN ga_account_currency AS a
	ON s.customer_id = a.account_id
GROUP BY 1,2,3
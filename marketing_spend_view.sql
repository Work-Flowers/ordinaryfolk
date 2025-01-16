WITH ga_targeting AS (
    SELECT
        campaign_id,
        geo_target_constant_id,
        ROW_NUMBER() OVER (
            PARTITION BY campaign_id
            ORDER BY updated_at DESC
        ) AS row_num
    FROM
        google_ads.campaign_criterion_history
    WHERE geo_target_constant_id IS NOT NULL
),
ga_latest_targeting AS (
    SELECT
        campaign_id,
        geo_target_constant_id
    FROM
        ga_targeting
    WHERE row_num = 1 -- Take the most recent targeting per campaign
),
ga_account_currency AS (
    SELECT
        id AS account_id,
        currency_code,
        ROW_NUMBER() OVER (
            PARTITION BY id
            ORDER BY updated_at DESC
        ) AS row_num
    FROM
        google_ads.account_history
),
ga_latest_currency AS (
    SELECT
        account_id,
        currency_code
    FROM
        ga_account_currency
    WHERE row_num = 1 -- Take the most recent account record per account
),

fb_account_currency AS (
    SELECT
        CAST(id AS STRING) AS account_id,
        currency,
        ROW_NUMBER() OVER (
            PARTITION BY id
            ORDER BY created_time DESC
        ) AS row_num
    FROM
        facebook_ads.account_history
),
fb_latest_currency AS (
    SELECT
        account_id,
        currency
    FROM
        fb_account_currency
    WHERE row_num = 1 -- Take the most recent account record per account
)

SELECT
    'google_ads' AS channel,
    s.date,
    a.currency_code,
    g.country_code,
    SUM(s.cost_micros) / 1000000 AS cost_local -- Convert micros to standard currency
FROM
    google_ads.ad_stats s
LEFT JOIN ga_latest_targeting c
    ON s.campaign_id = c.campaign_id
LEFT JOIN google_ads.geo_target g
    ON c.geo_target_constant_id = g.id
LEFT JOIN ga_latest_currency a
    ON s.customer_id = a.account_id
GROUP BY 1,2,3,4

UNION ALL

SELECT
    'facebook_ads' AS channel,
    d.date,
    a.currency AS currency_code,
    d.country AS country_code,
    SUM(spend) AS cost_local
FROM
    facebook_ads.demographics_country d
LEFT JOIN fb_latest_currency a
    ON d.account_id = a.account_id
GROUP BY 1,2,3,4
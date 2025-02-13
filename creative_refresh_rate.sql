WITH ads AS(
    SELECT
        CAST(id AS STRING) AS ad_id,
        creative_id,
        campaign_id,
        ad_set_id
    FROM noah-e30be.facebook_ads.ad_history
    QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _fivetran_synced) = 1
),

campaigns AS (
    SELECT
        id AS campaign_id,
        objective
    FROM noah-e30be.facebook_ads.campaign_history
    QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _fivetran_synced) = 1

),

adsets AS (
    SELECT
        id AS adset_id,
        optimization_goal,
        promoted_object_custom_event_type
    FROM noah-e30be.facebook_ads.ad_set_history
    QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _fivetran_synced) = 1
)

SELECT
    ba.date,
    CASE
        WHEN LOWER(acc.name) LIKE '%zoey%' THEN 'Zoey'
        WHEN LOWER(acc.name) LIKE '%noah%' THEN 'Noah'
        ELSE acc.name
        END AS brand,
    cr.id AS creative_id,
    CASE 
    	WHEN ch.objective = 'OUTCOME_SALES' THEN 'Sales'
    	WHEN ch.objective = 'OUTCOME_AWARENESS' THEN 'Awareness'
        WHEN ch.objective = 'OUTCOME_ENGAGEMENT' THEN 'Engagement'
    	ELSE ch.objective
    	END AS objective,
    adsets.optimization_goal,
    adsets.promoted_object_custom_event_type,
    MIN(ba.date) OVER (PARTITION BY cr.id) AS create_date
FROM facebook_ads.creative_history AS cr
INNER JOIN ads AS ah
	ON cr.id = ah.creative_id
INNER JOIN facebook_ads.basic_ad AS ba
    ON ah.ad_id = ba.ad_id
    AND ba.impressions > 0 -- only include rows where impressions were served
LEFT JOIN campaigns AS ch
	ON ah.campaign_id = ch.campaign_id
LEFT JOIN facebook_ads.account_history AS acc
    ON ba.account_id = acc.id
LEFT JOIN adsets
    ON ah.ad_set_id = adsets.adset_id
GROUP BY 1,2,3,4,5,6
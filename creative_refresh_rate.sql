SELECT
    ba.date,
    CASE 
    	WHEN ch.objective = 'OUTCOME_SALES' THEN 'Sales'
    	WHEN ch.objective = 'OUTCOME_AWARENESS' THEN 'Awareness'
    	ELSE ch.objective
    	END AS objective,
    COUNT(DISTINCT ah.id) AS ad_count,
    COUNT(DISTINCT cr.id) AS creative_count
FROM facebook_ads.basic_ad AS ba
INNER JOIN facebook_ads.ad_history AS ah 
	ON ba.ad_id = CAST(ah.id AS STRING)
INNER JOIN facebook_ads.creative_history AS cr 
	ON ah.creative_id = cr.id
LEFT JOIN facebook_ads.campaign_history AS ch 
	ON ah.campaign_id = ch.id
GROUP BY 1,2
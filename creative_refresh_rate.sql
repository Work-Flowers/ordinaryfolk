SELECT
    ba.date,
    cr.id AS creative_id,
    CASE 
    	WHEN ch.objective = 'OUTCOME_SALES' THEN 'Sales'
    	WHEN ch.objective = 'OUTCOME_AWARENESS' THEN 'Awareness'
    	ELSE ch.objective
    	END AS objective,
    MIN(ba.date) OVER (PARTITION BY cr.id) AS create_date
FROM facebook_ads.creative_history AS cr
INNER JOIN facebook_ads.ad_history AS ah
	ON cr.id = ah.creative_id
INNER JOIN facebook_ads.basic_ad AS ba
    ON CAST(ah.id AS STRING) = ba.ad_id
    AND ba.impressions > 0 -- only include rows where impressions were served
LEFT JOIN facebook_ads.campaign_history AS ch
	ON ah.campaign_id = ch.id
GROUP BY 1,2,3
ORDER BY 2,1
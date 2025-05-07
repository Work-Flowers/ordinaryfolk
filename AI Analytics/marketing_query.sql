SELECT
	DATE_TRUNC(cpa.date, MONTH) AS date,
	cpa.channel,
	cpa.country,
	cpa.condition,
	SUM(ROUND(cpa.cost_usd, 0)) AS ad_spend,
	SUM(cpa.ad_impressions) AS ad_impressions,
	SUM(ROUND(cpa.clicks,0)) AS ad_clicks,
	SUM(cpa.n_checkouts_completed) AS n_checkouts_completed,
	SUM(cpa.n_consults) AS n_consultations,
	SUM(cpa.n_q3_completions) AS n_q3_completions
FROM cac.marketing_cost_per_action AS cpa
WHERE 
	DATE_TRUNC(cpa.date, MONTH) >= DATE_SUB(DATE_TRUNC(CURRENT_DATE, MONTH), INTERVAL 12 MONTH)
	AND DATE_TRUNC(cpa.date, MONTH) < DATE_TRUNC(CURRENT_DATE, MONTH)
GROUP BY 1,2,3,4
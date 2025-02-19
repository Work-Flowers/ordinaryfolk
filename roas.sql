
WITH revenue AS(
	SELECT
		DATE_TRUNC(purchase_date, month) AS date,
		region AS country,
		SUM(COALESCE(line_item_amount_usd, total_charge_amount_usd)) AS revenue
	FROM finance_metrics.contribution_margin
	GROUP BY 1,2
),

acq AS (
	SELECT
		purchase_date,
		customer_id,
		region AS country,
		SUM(COALESCE(line_item_amount_usd, total_charge_amount_usd)) AS first_purchase
	FROM finance_metrics.contribution_margin
	GROUP BY 1,2,3
	QUALIFY ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY purchase_date) = 1

),

marketing AS (
	SELECT
		DATE_TRUNC(date, MONTH) AS date,
		LOWER(country_code) AS country,
		SUM(cost_usd) AS spend
	FROM cac.marketing_spend
	GROUP BY 1,2
)

SELECT 
	revenue.date,
	revenue.country,
	revenue.revenue,
	marketing.spend AS marketing_spend,
	COUNT(DISTINCT acq.customer_id) AS n_new_customers,
	SUM(acq.first_purchase) AS first_purchase_revenue
FROM revenue
INNER JOIN marketing		
	ON revenue.date = marketing.date
	AND revenue.country = marketing.country
LEFT JOIN acq
	ON revenue.date = DATE_TRUNC(acq.purchase_date, MONTH)
	AND revenue.country = acq.country
GROUP BY 1,2,3,4


WITH revenue AS(
	SELECT
		DATE_TRUNC(purchase_date, month) AS date,
		region AS country,
		SUM(COALESCE(line_item_amount_usd, total_charge_amount_usd)) AS revenue
	FROM finance_metrics.contribution_margin
	GROUP BY 1,2
),

monthly_cust_rev AS (
	SELECT
		DATE_TRUNC(purchase_date, MONTH) AS purchase_month,
		customer_id,
		region AS country,
		SUM(COALESCE(line_item_amount_usd, total_charge_amount_usd)) AS monthly_rev
	FROM finance_metrics.contribution_margin
	GROUP BY 1,2,3
	
),

acq AS (
	SELECT *
	FROM monthly_cust_rev
	QUALIFY ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY purchase_month) = 1
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
	SUM(acq.monthly_rev) AS first_purchase_revenue
FROM revenue
INNER JOIN marketing		
	ON revenue.date = marketing.date
	AND revenue.country = marketing.country
LEFT JOIN acq
	ON revenue.date = acq.purchase_month
	AND revenue.country = acq.country
GROUP BY 1,2,3,4

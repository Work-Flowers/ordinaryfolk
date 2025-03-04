WITH cohorts AS (
	SELECT 
		sales_channel,
		region,
		customer_id,
		DATE_TRUNC(purchase_date, MONTH) AS purchase_month,
		purchase_type,
		billing_reason,
		SUM(COALESCE(line_item_amount_usd, total_charge_amount_usd)) AS revenue,
		MIN(MIN(DATE_TRUNC(purchase_date, MONTH))) OVER (PARTITION BY customer_id) AS cohort_month
	FROM finance_metrics.contribution_margin
	WHERE 
		total_charge_amount_usd > 0
		AND DATE_TRUNC(purchase_date, MONTH) < DATE_TRUNC(CURRENT_DATE, MONTH)
	GROUP BY 1,2,3,4,5,6
),

cohorts_tagged AS (
	SELECT 
		cohorts.*,
		CASE 
			WHEN purchase_month = cohort_month THEN 'New'
			ELSE 'Existing'
			END AS customer_type
	FROM cohorts
)

SELECT
	region,
	sales_channel,
	purchase_month,
	purchase_type,
	billing_reason,
	customer_type,
	COUNT(DISTINCT customer_id) AS n_customers,
	SUM(revenue) AS revenue
FROM cohorts_tagged
-- WHERE region = 'sg'
GROUP BY 1,2,3,4,5,6

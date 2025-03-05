WITH cohorts AS (
	SELECT 
		sales_channel,
		region,
		customer_id,
		DATE_TRUNC(purchase_date, MONTH) AS purchase_month,
		purchase_type,
		billing_reason,
		currency,
		SUM(COALESCE(line_item_amount_usd, total_charge_amount_usd)) AS revenue_usd,
		MIN(MIN(DATE_TRUNC(purchase_date, MONTH))) OVER (PARTITION BY customer_id) AS cohort_month
	FROM finance_metrics.contribution_margin
	WHERE 
		1 = 1
		AND DATE_TRUNC(purchase_date, MONTH) < DATE_TRUNC(CURRENT_DATE, MONTH)
		AND COALESCE(line_item_amount_usd, total_charge_amount_usd) > 0
	GROUP BY 1,2,3,4,5,6,7
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
	ct.region,
	ct.sales_channel,
	ct.purchase_month,
	ct.purchase_type,
	ct.billing_reason,
	ct.customer_type,
	ct.currency,
	COUNT(DISTINCT ct.customer_id) AS n_customers,
	SUM(ct.revenue_usd) AS revenue_usd,
	SUM(ct.revenue_usd * fx.fx_to_usd) AS revenue_local
FROM cohorts_tagged AS ct
LEFT JOIN ref.fx_rates AS fx
	ON ct.currency = fx.currency
WHERE region = 'sg'
GROUP BY 1,2,3,4,5,6,7

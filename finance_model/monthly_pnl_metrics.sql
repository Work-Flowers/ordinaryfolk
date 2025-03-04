WITH cohorts AS (
	SELECT 
		customer_id,
		DATE_TRUNC(purchase_date, month) AS purchase_month,
		SUM(COALESCE(line_item_amount_usd, total_charge_amount_usd)) AS revenue,
		MIN(MIN(DATE_TRUNC(purchase_date, MONTH))) OVER (PARTITION BY customer_id) AS cohort_month
	FROM finance_metrics.contribution_margin
	WHERE total_charge_amount_usd > 0
	GROUP BY 1,2
	ORDER BY 1,2
)
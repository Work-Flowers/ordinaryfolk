WITH monthly_rev AS (
	SELECT
		cm.customer_id,
		DATE_TRUNC(purchase_date, MONTH) AS date,
		SUM(COALESCE(cm.line_item_amount_usd, total_charge_amount_usd)) AS rev
	FROM finance_metrics.contribution_margin AS cm
	WHERE 
		sales_channel = 'Stripe'
	GROUP BY 1,2
)

SELECT
	customer_id,
	date,
	rev,
	MIN(date) OVER(PARTITION BY customer_id) AS acq_date,
	SUM(rev) OVER (PARTITION BY customer_id ORDER BY  date) AS cum_rev
FROM monthly_rev
GROUP BY 1,2,3
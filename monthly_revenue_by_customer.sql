WITH sub_starts AS (
	SELECT DISTINCT
		h.id AS subscription_id,
		DATE_TRUNC(DATE(h.created), MONTH) AS create_date,
		pl.interval,
		pl.interval_count
	FROM all_stripe.subscription_history AS h
	LEFT JOIN all_stripe.subscription_item AS i
		ON h.id = i.subscription_id
	LEFT JOIN all_stripe.plan AS pl
		ON i.plan_id = pl.id
)

SELECT
	DATE_TRUNC(cm.purchase_date, MONTH) AS purchase_month,
	cm.sales_channel,
	cm.region,
	cm.new_existing,
	cm.customer_id,
	cm.charge_id,
	cm.subscription_id,
	cm.condition,
	cm.product_name,
	cm.billing_reason,
	cm.purchase_type,
	sub_starts.create_date AS subscription_created,
	sub_starts.interval,
	sub_starts.interval_count,
	SUM(COALESCE(cm.line_item_amount_usd, cm.total_charge_amount_usd)) AS revenue_usd,
	MIN(MIN(DATE_TRUNC(cm.purchase_date, MONTH))) OVER(PARTITION BY customer_id) AS cohort_month
FROM finance_metrics.contribution_margin AS cm
LEFT JOIN sub_starts
	ON cm.subscription_id = sub_starts.subscription_id
WHERE
	1 = 1
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14

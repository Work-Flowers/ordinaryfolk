DROP VIEW IF EXISTS all_stripe.subscription_renewals;
CREATE VIEW all_stripe.subscription_renewals AS 

WITH sub_starts AS (
	SELECT DISTINCT
		region,
		created,
		id AS subscription_id
	FROM all_stripe.subscription_history
)

SELECT
	sub_starts.region,
	DATE(sub_starts.created) AS created_date,
	sub_starts.subscription_id,
	cm.condition,
	COUNT(DISTINCT cm.charge_id) AS n_charges_in_first_90d,
	SUM(COALESCE(cm.line_item_amount_usd, cm.total_charge_amount_usd)) AS amount_usd_in_first_90d
FROM sub_starts
LEFT JOIN finance_metrics.contribution_margin AS cm
	ON cm.subscription_id = sub_starts.subscription_id
	AND cm.purchase_date <= DATE_ADD(DATE(sub_starts.created), INTERVAL 90 DAY)
GROUP BY 1,2,3,4
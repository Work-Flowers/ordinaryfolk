DROP VIEW IF EXISTS all_stripe.subscription_renewals;
CREATE VIEW all_stripe.subscription_renewals AS 

WITH sub_starts AS (
	SELECT
		subscription_id,
		region,
		condition,
		MIN(purchase_date) AS created
	FROM finance_metrics.contribution_margin
	WHERE
		subscription_id IS NOT NULL
		AND COALESCE(line_item_amount_usd, total_charge_amount_usd) > 0
	GROUP BY 1,2,3
)

SELECT
	sub_starts.region,
	DATE(sub_starts.created) AS created_date,
	sub_starts.subscription_id,
	sub_starts.condition,
	COUNT(DISTINCT cm.charge_id) AS n_charges_in_first_90d,
	SUM(COALESCE(cm.line_item_amount_usd, cm.total_charge_amount_usd, 0)) AS amount_usd_in_first_90d
FROM sub_starts
LEFT JOIN finance_metrics.contribution_margin AS cm
	ON sub_starts.subscription_id = cm.subscription_id
	AND sub_starts.condition = cm.condition
	AND DATE_ADD(DATE(sub_starts.created), INTERVAL 90 DAY) >= cm.purchase_date
	AND DATE(sub_starts.created) < cm.purchase_date
GROUP BY 1,2,3,4


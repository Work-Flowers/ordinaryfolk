DROP VIEW IF EXISTS all_stripe.subscription_renewals;
CREATE VIEW all_stripe.subscription_renewals AS 

WITH sub_starts AS (
	SELECT DISTINCT
		created,
		id AS subscription_id
	FROM all_stripe.subscription_history
)

SELECT
	DATE(sub_starts.created) AS created_date,
	sub_starts.subscription_id,
	COUNT(DISTINCT ch.id) AS n_charges_in_first_90d,
	SUM(ch.amount / fx.fx_to_usd / COALESCE(su.subunits, 100)) AS amount_usd_in_first_90d
FROM sub_starts
LEFT JOIN all_stripe.invoice AS inv
	ON sub_starts.subscription_id = inv.subscription_id
LEFT JOIN all_stripe.charge AS ch
	ON inv.id = ch.invoice_id
	AND DATE(ch.created) <= DATE_ADD(DATE(sub_starts.created), INTERVAL 90 DAY)
	AND DATE(ch.created) > DATE(sub_starts.created)
LEFT JOIN ref.fx_rates AS fx
	ON inv.currency = fx.currency
LEFT JOIN ref.stripe_currency_subunits AS su
	ON inv.currency = su.currency
GROUP BY 1,2
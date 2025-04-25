DROP VIEW IF EXISTS finance_metrics.monthly_contribution_margin;
CREATE VIEW finance_metrics.monthly_contribution_margin AS 

WITH cm1 AS (
	SELECT
		region AS country,
		DATE_TRUNC(purchase_date, MONTH) AS date,
		purchase_type,
		COALESCE(condition, 'N/A') AS condition,
		SUM(COALESCE(line_item_amount_usd, total_charge_amount_usd)) AS amount,
		SUM(cogs * quantity) AS cogs,
		SUM(packaging) AS packaging,
		SUM(cashback) AS cashback,
		-- correct the calculation of tax amount paid, since Stripe line item and charge amounts are inclusive of tax
		SUM(
			(COALESCE(line_item_amount_usd, total_charge_amount_usd) - amount_refunded_usd)  * (1 - 1 / (1 + gst_vat))
		) AS tax_paid_usd,
		SUM(COALESCE(line_item_amount_usd, total_charge_amount_usd) * fee_rate) AS payment_gateway_fees,
		SUM(cm.amount_refunded_usd) AS refunds
	FROM finance_metrics.contribution_margin AS cm
-- 	WHERE purchase_type = 'Subscription'
	GROUP BY 1,2,3,4
),

cm1_with_teleconsult_fees AS (
	SELECT
		cm1.country,
		cm1.date,
		cm1.condition,
		cm1.amount,
		cm1.purchase_type,
		COALESCE(cm1.cogs, -op.teleconsultation_fees / fx.fx_to_usd) AS cogs,
		cm1.packaging,
		cm1.cashback,
		cm1.tax_paid_usd,
		cm1.payment_gateway_fees,
		cm1.refunds
	FROM cm1
	LEFT JOIN google_sheets.opex AS op
		ON cm1.date = op.date
		AND cm1.country = op.country
		AND cm1.condition = 'Services'
	LEFT JOIN ref.fx_rates AS fx
		ON LOWER(op.currency) = fx.currency
),

delivery AS (
	SELECT
		DATE_TRUNC(dc.date, MONTH) AS date,
		dc.country,
		SUM(dc.cost / fx.fx_to_usd) AS cost
	FROM google_sheets.delivery_cost AS dc
	LEFT JOIN ref.fx_rates AS fx
		ON LOWER(dc.currency) = LOWER(fx.currency)
	GROUP BY 1,2
),

marketing AS (
	SELECT
		DATE_TRUNC(date, MONTH) AS date,
		LOWER(country_code) AS country,
		COALESCE(condition, 'N/A') AS condition,
		SUM(cost_usd) AS cost
	FROM cac.marketing_spend
	GROUP BY 1,2,3

)

SELECT
	cwt.*,
	delivery.cost * cwt.amount / SUM(cwt.amount) OVER (PARTITION BY cwt.date, cwt.country) AS delivery_cost,
	mar.cost * cwt.amount / SUM(cwt.amount) OVER (PARTITION BY cwt.date, cwt.country, cwt.condition) AS marketing_cost
FROM cm1_with_teleconsult_fees AS cwt
LEFT JOIN delivery
	ON cwt.date = delivery.date
	AND cwt.country = delivery.country
LEFT JOIN marketing AS mar
	ON cwt.date = mar.date
	AND cwt.country = mar.country
	AND cwt.condition = mar.condition

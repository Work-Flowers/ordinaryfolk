DROP VIEW IF EXISTS finance_metrics.monthly_contribution_margin;
CREATE VIEW finance_metrics.monthly_contribution_margin AS 

WITH cm1 AS (
	SELECT
		region AS country,
		DATE_TRUNC(purchase_date, MONTH) AS date,
		purchase_type,
		COALESCE(condition, 'N/A') AS condition,
		SUM(COALESCE(line_item_amount_usd, total_charge_amount_usd)) AS amount,
		SUM(cogs) AS cogs,
		SUM(packaging) AS packaging,
		SUM(cashback) AS cashback,
		SUM(COALESCE(line_item_amount_usd, total_charge_amount_usd) * gst_vat) AS gst_vat,
		SUM(COALESCE(line_item_amount_usd, total_charge_amount_usd) * fee_rate) AS payment_gateway_fees,
		SUM(cm.amount_refunded_usd) AS refunds
	FROM finance_metrics.contribution_margin AS cm
	WHERE purchase_type = 'Subscription'
	GROUP BY 1,2,3,4
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
	cm1.*,
	delivery.cost * cm1.amount / SUM(cm1.amount) OVER (PARTITION BY cm1.date, cm1.country) AS delivery_cost,
	mar.cost * cm1.amount / SUM(cm1.amount) OVER (PARTITION BY cm1.date, cm1.country, cm1.condition) AS marketing_cost
FROM cm1
LEFT JOIN delivery
	ON cm1.date = delivery.date
	AND cm1.country = delivery.country
LEFT JOIN marketing AS mar
	ON cm1.date = mar.date
	AND cm1.country = mar.country
	AND cm1.condition = mar.condition
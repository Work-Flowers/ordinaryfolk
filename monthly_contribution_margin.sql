DROP VIEW IF EXISTS finance_metrics.monthly_contribution_margin;
CREATE VIEW finance_metrics.monthly_contribution_margin AS 

WITH cm1 AS (
	SELECT
		region AS country,
		DATE_TRUNC(purchase_date, MONTH) AS date,
		SUM(COALESCE(line_item_amount_usd, total_charge_amount_usd)) AS amount,
		SUM(cogs) AS cogs,
		SUM(packaging) AS packaging,
		SUM(cashback) AS cashback,
		SUM(gst_vat) AS gst_vat,
		SUM(COALESCE(line_item_amount_usd, total_charge_amount_usd) * fee_rate) AS payment_gateway_fees,
		SUM(COALESCE(line_item_amount_usd, total_charge_amount_usd) * refund_rate) AS refunds
	FROM finance_metrics.contribution_margin
	GROUP BY 1,2
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
)

SELECT

	cm1.*,
	delivery.cost AS delivery_cost
FROM cm1
LEFT JOIN delivery
	ON cm1.date = delivery.date
	AND cm1.country = delivery.country
-- query for CM2 and 3 calculations at monthly level (some required inputs are not available at more frequent intervals)

WITH main AS (
	SELECT
		DATE_TRUNC(fin.purchase_date, MONTH) AS date,
		fin.sales_channel,
		fin.region AS country,
		SUM(COALESCE(fin.line_item_amount_usd, fin.total_charge_amount_usd)) AS purchase_amount,
		SUM(fin.cogs) AS cogs,
		SUM(fin.gst_vat) AS gst_vat,
		SUM(COALESCE(fin.line_item_amount_usd, fin.total_charge_amount_usd) * fin.fee_rate) AS payment_gateway_fees,
		SUM(COALESCE(fin.line_item_amount_usd, fin.total_charge_amount_usd) * fin.refund_rate) AS refunds
	FROM finance_metrics.contribution_margin AS fin
	GROUP BY 1,2,3
),

dc AS (
	SELECT
		del.date,
		del.country,
		del.cost / fx.fx_to_usd AS cost
	FROM google_sheets.delivery_cost AS del
	LEFT JOIN ref.fx_rates AS fx
		ON LOWER(del.currency) = LOWER(fx.currency)
)

SELECT
	main.*,
	dc.cost AS delivery_cost
FROM main
LEFT JOIN dc
	ON main.date = dc.date
	AND main.country = dc.country
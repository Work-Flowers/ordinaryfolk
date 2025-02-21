DROP VIEW IF EXISTS finance_metrics.direct_variable_cost;
CREATE VIEW finance_metrics.direct_variable_cost AS 

WITH payment_gateway_fees AS (
	SELECT
		cm.region AS country,
		DATE(DATE_TRUNC(cm.purchase_date, MONTH)) AS date,
		SUM(cm.fee_rate * cm.line_item_amount_usd) AS cost
	FROM finance_metrics.contribution_margin AS cm
	GROUP BY 1,2
),

packaging AS (
	SELECT
		cm.region AS country,
		DATE(DATE_TRUNC(cm.purchase_date, MONTH)) AS date,
		SUM(cm.packaging) AS cost		
	FROM finance_metrics.contribution_margin AS cm
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
	date,
	country,
	'Payment Gateway Fees' AS type,
	cost 
FROM payment_gateway_fees

UNION ALL

SELECT
	date,
	country,
	'Packaging' AS type,
	cost 
FROM packaging

UNION ALL

SELECT
	date,
	country,
	'Delivery' AS type,
	cost 
FROM delivery
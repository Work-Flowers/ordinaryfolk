DROP VIEW IF EXISTS finance_metrics.direct_variable_cost;
CREATE VIEW finance_metrics.direct_variable_cost AS 

WITH pay_pack AS (
	SELECT
		cm.region AS country,
		DATE(DATE_TRUNC(cm.purchase_date, MONTH)) AS date,
		SUM(cm.fee_rate * cm.line_item_amount_usd) AS fees,
		SUM(cm.packaging) AS packaging		
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
	pay_pack.*,
	delivery.cost AS delivery_cost
FROM pay_pack 
LEFT JOIN delivery
	ON pay_pack.date = delivery.date
	AND pay_pack.country = delivery.country
DROP VIEW IF EXISTS finance_metrics.direct_variable_cost;
CREATE VIEW finance_metrics.direct_variable_cost AS 

WITH payment_gateway_fees AS (
	SELECT
		cm.country,
		cm.date,
		SUM(cm.gateway_fees) AS cost
	FROM finance_metrics.monthly_contribution_margin AS cm
	GROUP BY 1,2
),

packaging AS (
	SELECT
		cm.country,
		cm.date,
		SUM(cm.packaging) AS cost		
	FROM finance_metrics.monthly_contribution_margin AS cm
	GROUP BY 1,2
),

delivery AS (
	SELECT
		cm.country,
		cm.date,
		SUM(cm.delivery_cost) AS cost		
	FROM finance_metrics.monthly_contribution_margin AS cm
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
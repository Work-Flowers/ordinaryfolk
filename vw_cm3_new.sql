DROP VIEW IF EXISTS finance_metrics.cm3;
CREATE VIEW finance_metrics.cm3 AS 

WITH base AS (
  SELECT
    region AS country,
    DATE_TRUNC(purchase_date, MONTH) AS purchase_month,
    new_existing,
    purchase_type,
    condition,
    customer_id,
    COALESCE(line_item_amount_usd, total_charge_amount_usd) AS amount,
    cogs,
    packaging,
    cashback,
    gst_vat,
    fee_rate,
    amount_refunded_usd,
    MIN(DATE_TRUNC(purchase_date, MONTH)) OVER(PARTITION BY customer_id) AS acq_month
  FROM finance_metrics.contribution_margin
  WHERE customer_id IS NOT NULL
),

cm1 AS (
	SELECT
	  country,
	  purchase_month,
	  acq_month,
	  new_existing,
	  purchase_type,
	  condition,
	  customer_id,
	  SUM(amount) AS revenue,
	  SUM(cogs) AS cogs,
	  SUM(packaging) AS packaging,
	  SUM(cashback) AS cashback,
	  SUM(amount * (1 - 1 / (1+ gst_vat))) AS gst_vat,
	  SUM(amount * fee_rate) AS payment_gateway_fees,
	  SUM(amount_refunded_usd) AS refunds
	FROM base
	GROUP BY 1,2,3,4,5,6,7
),

delivery AS (
	SELECT
		DATE_TRUNC(dc.date, MONTH) AS date,
		dc.country,
		SUM(dc.cost / fx.fx_to_usd) AS total_delivery_cost
	FROM google_sheets.delivery_cost AS dc
	LEFT JOIN ref.fx_rates AS fx
		ON LOWER(dc.currency) = LOWER(fx.currency)
	GROUP BY 1,2
),

marketing AS (
	SELECT
		DATE_TRUNC(date, MONTH) AS date,
		LOWER(country_code) AS country,
		SUM(cost_usd) AS cost
	FROM cac.marketing_spend
	GROUP BY 1,2

)

SELECT
	cm1.*,
	d.total_delivery_cost,
	m.cost AS total_marketing_cost,
	
	-- prorate delivery costs by revenue within each purchase month and country
	SAFE_DIVIDE(cm1.revenue, 
	  SUM(cm1.revenue) OVER (PARTITION BY cm1.purchase_month, cm1.country)
	) * d.total_delivery_cost AS prorated_delivery_cost,
	
	-- prorate delivery costs by revenue within each acquisition month and country
	SAFE_DIVIDE(cm1.revenue, 
	  SUM(cm1.revenue) OVER (PARTITION BY cm1.acq_month, cm1.purchase_month, cm1.country)
	) * COALESCE(m.cost, 0) AS prorated_marketing_cost
FROM cm1
LEFT JOIN delivery AS d
	ON cm1.purchase_month = d.date
	AND cm1.country = d.country
LEFT JOIN marketing AS m
	ON cm1.acq_month = m.date
	AND cm1.purchase_month = m.date
	AND cm1.country = m.country

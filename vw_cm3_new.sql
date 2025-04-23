DROP VIEW IF EXISTS finance_metrics.cm3;
CREATE VIEW finance_metrics.cm3 AS 

WITH base AS (
  SELECT
    sales_channel,
    region AS country,
    DATE_TRUNC(purchase_date, MONTH) AS purchase_month,
    new_existing,
    billing_reason,
    purchase_type,
    condition,
    currency,
    customer_id,
    charge_id,
    COALESCE(line_item_amount_usd, total_charge_amount_usd) AS amount,
    cogs,
    packaging,
    cashback,
    gst_vat,
    fee_rate,
    amount_refunded_usd,
    MIN(DATE_TRUNC(purchase_date, MONTH)) OVER(PARTITION BY customer_id) AS acq_month
  FROM finance_metrics.contribution_margin
--   WHERE customer_id IS NOT NULL
),

cm1 AS (
	SELECT
	  sales_channel,
	  country,
	  purchase_month,
	  purchase_type,
	  acq_month,
	  new_existing,
	  billing_reason,
	  condition,
	  currency,
	  customer_id,
	  charge_id,
	  gst_vat AS gst_vat_rate,
	  SUM(amount) AS revenue,
	  SUM(cogs) AS cogs,
	  SUM(packaging) AS packaging,
	  SUM(cashback) AS cashback,
	  SUM((amount - amount_refunded_usd) * (1 - 1 / (1+ gst_vat))) AS gst_vat,
	  SUM(amount * fee_rate) AS payment_gateway_fees,
	  SUM(amount_refunded_usd) AS refunds
	FROM base
	GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12
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

),

opex AS (
	SELECT
		DATE_TRUNC(o.date, MONTH) AS date,
		LOWER(o.country) AS country,
		-SUM(o.teleconsultation_fees / fx.fx_to_usd) AS teleconsultation_fees,
		-SUM(o.dispensing_fees / fx.fx_to_usd) AS dispensing_fees,
		-SUM(o.operating_expense / fx.fx_to_usd) AS operating_expense,
		-SUM(o.staff_cost / fx.fx_to_usd) AS staff_cost
	FROM google_sheets.opex AS o
	LEFT JOIN ref.fx_rates AS fx
		ON LOWER(o.currency) = fx.currency
	WHERE
		o.date IS NOT NULL
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
	) * COALESCE(m.cost, 0) AS prorated_marketing_cost,
	
	-- prorate teleconsultation_fees by revenue within each purchase month and country
	SAFE_DIVIDE(cm1.revenue, 
	  SUM(cm1.revenue) OVER (PARTITION BY cm1.purchase_month, cm1.country)
	) * opex.teleconsultation_fees AS teleconsultation_fees,
	
	-- prorate dispensing_fees by revenue within each purchase month and country
	SAFE_DIVIDE(cm1.revenue, 
	  SUM(cm1.revenue) OVER (PARTITION BY cm1.purchase_month, cm1.country)
	) * opex.dispensing_fees AS dispensing_fees,
	
	-- prorate operating_expense by revenue within each purchase month and country
	SAFE_DIVIDE(cm1.revenue, 
	  SUM(cm1.revenue) OVER (PARTITION BY cm1.purchase_month, cm1.country)
	) * opex.operating_expense AS operating_expense,
	
	-- prorate staff_cost by revenue within each purchase month and country
	SAFE_DIVIDE(cm1.revenue, 
	  SUM(cm1.revenue) OVER (PARTITION BY cm1.purchase_month, cm1.country)
	) * opex.staff_cost AS staff_cost
	
FROM cm1
LEFT JOIN delivery AS d
	ON cm1.purchase_month = d.date
	AND cm1.country = d.country
LEFT JOIN marketing AS m
	ON cm1.acq_month = m.date
	AND cm1.purchase_month = m.date
	AND cm1.country = m.country
LEFT JOIN opex
	ON cm1.purchase_month = opex.date
	AND cm1.country = opex.country

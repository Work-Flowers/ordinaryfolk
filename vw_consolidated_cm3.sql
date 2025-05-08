-- DROP VIEW IF EXISTS finance_metrics.consolidated_cm3;
-- CREATE VIEW finance_metrics.consolidated_cm3 AS 

WITH

-- 1. RAW: compute all scalar fields + acq_month per customer
raw_data AS (
  SELECT
    region AS country,
    DATE_TRUNC(purchase_date, MONTH) AS month,
    purchase_type,
    COALESCE(new_existing, 'New') AS new_existing,
    sales_channel,
    COALESCE(condition, 'N/A') AS condition,
    customer_id,
    charge_id,
    COALESCE(line_item_amount_usd, total_charge_amount_usd) AS amount,
    cogs * quantity AS cogs,
    packaging,
    cashback,
    amount_refunded_usd,
    fee_rate,
    gst_vat,
    -- first purchase month per customer
    MIN(DATE_TRUNC(purchase_date, MONTH)) OVER (PARTITION BY customer_id) AS acq_month
  FROM finance_metrics.contribution_margin
),

-- 2. BASE: aggregate all the sums and counts, now that acq_month is just a column
base AS (
	SELECT
		country,
		month,
		purchase_type,
		new_existing,
		sales_channel,
		condition,
		acq_month,
		customer_id,
		SUM(amount) AS amount,
		SUM(COALESCE(cogs,0)) AS cogs,
		SUM(packaging) AS packaging,
		SUM(cashback) AS cashback,
		SUM((amount - amount_refunded_usd) * (1 - 1 / (1 + gst_vat))) AS tax_paid_usd,
		SUM(amount * fee_rate) AS gateway_fees,
		SUM(amount_refunded_usd) AS refunds,
		COUNT(DISTINCT charge_id) AS n_orders
	FROM raw_data
	GROUP BY 1,2,3,4,5,6,7,8
),

-- 3. Delivery costs by month & country
delivery AS (
	SELECT
		DATE_TRUNC(dc.date, MONTH) AS MONTH,
		LOWER(dc.country) AS country,
		SUM(dc.cost / fx.fx_to_usd) AS total_delivery_cost
	FROM google_sheets.delivery_cost dc
	JOIN ref.fx_rates AS fx
		ON LOWER(dc.currency) = fx.currency
	GROUP BY 1,2
),

-- 4. Marketing costs by month, country & condition
marketing AS (
	SELECT
		DATE_TRUNC(DATE, MONTH) AS MONTH,
		LOWER(country_code) AS country,
		COALESCE(condition, 'N/A') AS condition,
		SUM(cost_usd) AS total_marketing_cost
	FROM cac.marketing_spend
	GROUP BY 1,2,3
),

-- 5. OPEX (teleconsult, dispensing, operating, staff)
opex AS (
	SELECT
		DATE_TRUNC(o.date, MONTH) AS MONTH,
		LOWER(o.country) AS country,
		- SUM(o.teleconsultation_fees / fx.fx_to_usd) AS teleconsultation_fees,
		- SUM(o.dispensing_fees / fx.fx_to_usd) AS dispensing_fees,
		- SUM(o.operating_expense / fx.fx_to_usd) AS operating_expense,
		- SUM(o.staff_cost / fx.fx_to_usd) AS staff_cost
	FROM google_sheets.opex o
	JOIN  ref.fx_rates AS fx 
		ON LOWER(o.currency) = fx.currency
	GROUP BY 1,2
)
SELECT
	b.* EXCEPT (cogs),
	CASE 
		WHEN b.condition = 'Services' THEN o.teleconsultation_fees * b.amount / SUM(b.amount) OVER (PARTITION BY b.country, b.month, b.condition)
		ELSE b.cogs
		END AS cogs,

	-- Base profitability
-- 	b.amount - b.refunds - b.tax_paid_usd AS net_revenue,
-- 	b.amount - b.refunds - b.tax_paid_usd - b.cogs AS gross_profit,  
	
	-- Prorated delivery cost
	SAFE_DIVIDE(
		b.amount,
		SUM(b.amount) OVER (PARTITION BY b.month, b.country)
	) * COALESCE(d.total_delivery_cost, 0) AS delivery_cost,
  
  -- Prorated marketing cost
	SAFE_DIVIDE(
		b.amount,
		SUM(b.amount) OVER (PARTITION BY b.month, b.country, b.condition)
	) * COALESCE(m.total_marketing_cost, 0) AS marketing_cost,
  
  -- Prorated OPEX lines
	SAFE_DIVIDE(
		b.amount,
		SUM(b.amount) OVER (PARTITION BY b.month, b.country)
	) * COALESCE(o.dispensing_fees, 0) AS dispensing_fees,
  
	SAFE_DIVIDE(
		b.amount,
		SUM(b.amount) OVER (PARTITION BY b.month, b.country)
	) * COALESCE(o.operating_expense, 0) AS operating_expense,
	SAFE_DIVIDE(
		b.amount,
		SUM(b.amount) OVER (PARTITION BY b.month, b.country)
	) * COALESCE(o.staff_cost, 0) AS staff_cost
FROM base AS b
LEFT JOIN delivery AS d 
	ON b.month = d.month
  	AND LOWER(b.country) = d.country
LEFT JOIN marketing AS m 
	ON b.month = m.month
	AND LOWER(b.country) = m.country
	AND b.condition = m.condition
LEFT JOIN opex AS o 
	ON b.month = o.month
	AND LOWER(b.country) = o.country;
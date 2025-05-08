DROP VIEW IF EXISTS finance_metrics.monthly_contribution_margin;
CREATE VIEW finance_metrics.monthly_contribution_margin AS 

WITH

-- 1. RAW: compute all scalar fields + acq_month per customer
raw_data AS (
  SELECT
    region AS country,
    DATE_TRUNC(purchase_date, MONTH) AS date,
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
		date,
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
		DATE_TRUNC(dc.date, MONTH) AS date,
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
		DATE_TRUNC(DATE, MONTH) AS date,
		LOWER(country_code) AS country,
		COALESCE(condition, 'N/A') AS condition,
		SUM(cost_usd) AS total_marketing_cost
	FROM cac.marketing_spend
	GROUP BY 1,2,3
),

-- 5. OPEX (teleconsult, dispensing, operating, staff)
opex AS (
	SELECT
		DATE_TRUNC(o.date, MONTH) AS date,
		LOWER(o.country) AS country,
		- SUM(o.teleconsultation_fees / fx.fx_to_usd) AS teleconsultation_fees,
		- SUM(o.dispensing_fees / fx.fx_to_usd) AS dispensing_fees,
		- SUM(o.operating_expense / fx.fx_to_usd) AS operating_expense,
		- SUM(o.staff_cost / fx.fx_to_usd) AS staff_cost
	FROM google_sheets.opex o
	JOIN  ref.fx_rates AS fx 
		ON LOWER(o.currency) = fx.currency
	GROUP BY 1,2
),

-- put it all together, and set COGS to teleconsult fee expense for Services transactions
base_with_opex AS (
	SELECT
		b.* EXCEPT (cogs),
		CASE 
			WHEN b.condition = 'Services' THEN o.teleconsultation_fees * b.amount / SUM(b.amount) OVER (PARTITION BY b.country, b.date, b.condition)
			ELSE b.cogs
			END AS cogs,
			
		-- Prorated delivery cost
		SAFE_DIVIDE(
			b.amount,
			SUM(b.amount) OVER (PARTITION BY b.date, b.country)
		) * COALESCE(d.total_delivery_cost, 0) AS delivery_cost, 
	  
	  -- Prorated marketing cost
		SAFE_DIVIDE(
			b.amount,
			SUM(b.amount) OVER (PARTITION BY b.date, b.country, b.condition)
		) * COALESCE(m.total_marketing_cost, 0) AS marketing_cost,
	  
	  -- Prorated OPEX lines
		SAFE_DIVIDE(
			b.amount,
			SUM(b.amount) OVER (PARTITION BY b.date, b.country)
		) * COALESCE(o.dispensing_fees, 0) AS dispensing_fees,
	  
		SAFE_DIVIDE(
			b.amount,
			SUM(b.amount) OVER (PARTITION BY b.date, b.country)
		) * COALESCE(o.operating_expense, 0) AS operating_expense,
		SAFE_DIVIDE(
			b.amount,
			SUM(b.amount) OVER (PARTITION BY b.date, b.country)
		) * COALESCE(o.staff_cost, 0) AS staff_cost
	FROM base AS b
	LEFT JOIN delivery AS d 
		ON b.date = d.date
	  	AND LOWER(b.country) = d.country
	LEFT JOIN marketing AS m 
		ON b.date = m.date
		AND LOWER(b.country) = m.country
		AND b.condition = m.condition
	LEFT JOIN opex AS o 
		ON b.date = o.date
		AND LOWER(b.country) = o.country
)

-- now select final output
SELECT
	bpo.* EXCEPT(amount, packaging, delivery_cost, gateway_fees),
	amount AS gross_revenue,
	amount - refunds - tax_paid_usd AS net_revenue,
	COALESCE(gateway_fees, 0) AS gateway_fees.
	COALESCE(packaging, 0) AS packaging,
	COALESCE(delivery_cost, 0) AS delivery_cost.
	amount - refunds - cogs AS gross_profit,
	amount - refunds - cogs - COALESCE(packaging, 0) - COALESCE(delivery_cost, 0) - COALESCE(gateway_fees, 0) AS cm2,
	amount - refunds - cogs - COALESCE(packaging, 0) - COALESCE(delivery_cost, 0) - COALESCE(gateway_fees, 0) - marketing_cost AS cm3,
	amount - refunds - cogs - COALESCE(packaging, 0) - COALESCE(delivery_cost, 0) - COALESCE(gateway_fees, 0) - marketing_cost  - operating_expense - staff_cost AS ebitda

FROM base_with_opex AS bpo
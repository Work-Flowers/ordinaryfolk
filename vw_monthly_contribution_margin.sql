DROP VIEW IF EXISTS finance_metrics.monthly_contribution_margin;
CREATE VIEW finance_metrics.monthly_contribution_margin AS

WITH sales_base AS (
	SELECT
		LOWER(region) AS country,
		DATE_TRUNC(purchase_date, MONTH) AS date,
		condition,
		COALESCE(line_item_amount_usd, total_charge_amount_usd) AS amount,
		COALESCE(cogs,0) * COALESCE(quantity,1) AS cogs,
		packaging,
		cashback,
		amount_refunded_usd,
		fee_rate,
		gst_vat,
		charge_id,
		sales_channel,
		currency,
		billing_reason,
		purchase_type,
	    new_existing,
        customer_id 
    FROM finance_metrics.contribution_margin
),

blocks AS (
  -- SALES BLOCK
 	SELECT
		'sales' AS source,
		date,
		country,
		condition,
		sales_channel,
		currency,
		billing_reason,
		purchase_type,
		new_existing,
		customer_id,
		SUM(amount) AS amount,
		SUM(cogs * (1 - SAFE_DIVIDE(amount_refunded_usd, amount))) AS cogs,
		SUM(packaging) AS packaging,
		SUM(cashback) AS cashback,
		SUM((amount - amount_refunded_usd) * (1 - 1 / (1 + gst_vat))) AS tax_paid_usd,
		SUM(amount * fee_rate) AS gateway_fees,
		SUM(amount_refunded_usd) AS refunds,
		COUNT(DISTINCT charge_id) AS n_orders,
	    0.0 AS marketing_cost,
	    0.0 AS delivery_cost,
	    0.0 AS dispensing_fees,
	    0.0 AS operating_expense,
	    0.0 AS staff_cost
	FROM sales_base
	GROUP BY 1,2,3,4,5,6,7,8,9,10
    
    UNION ALL

      -- MARKETING BLOCK
    SELECT
        'marketing' AS source,
        DATE_TRUNC(date, MONTH) AS date,
        LOWER(country_code) AS country,
        condition,
        CAST(NULL AS STRING) AS sales_channel,
        CAST(NULL AS STRING) AS currency,
        CAST(NULL AS STRING) AS billing_reason,
        CAST(NULL AS STRING) AS purchase_type,
        CAST(NULL AS STRING) AS new_existing,
        CAST(NULL AS STRING) AS customer_id,
        0.0 AS amount,
        0.0 AS cogs,
        0.0 AS packaging,
        0.0 AS cashback,
        0.0 AS tax_paid_usd,
        0.0 AS gateway_fees,
        0.0 AS refunds,
        0 AS n_orders,
        SUM(cost_usd) AS marketing_cost,
        0.0 AS delivery_cost,
        0.0 AS dispensing_fees,
        0.0 AS operating_expense,
        0.0 AS staff_cost
    FROM cac.marketing_spend
    GROUP BY 1,2,3,4

    UNION ALL

    -- DELIVERY BLOCK
    SELECT
        'delivery' AS source,
        DATE_TRUNC(dc.date, MONTH) AS date,
        LOWER(dc.country) AS country,
        CAST(NULL AS STRING) AS condition,
        CAST(NULL AS STRING) AS sales_channel,
        CAST(NULL AS STRING) AS currency,
        CAST(NULL AS STRING) AS billing_reason,
        CAST(NULL AS STRING) AS purchase_type,
        CAST(NULL AS STRING) AS new_existing,
        CAST(NULL AS STRING) AS customer_id,
        0.0 AS amount,
        0.0 AS cogs,
        0.0 AS packaging,
        0.0 AS cashback,
        0.0 AS tax_paid_usd,
        0.0 AS gateway_fees,
        0.0 AS refunds,
        0 AS n_orders,
        0.0 AS marketing_cost,
        SUM(dc.cost / fx.fx_to_usd) AS delivery_cost,
        0.0 AS dispensing_fees,
        0.0 AS operating_expense,
        0.0 AS staff_cost
    FROM google_sheets.delivery_cost dc
    JOIN ref.fx_rates AS fx ON LOWER(dc.currency) = fx.currency
    GROUP BY 1,2,3,4

    UNION ALL

    -- OPEX BLOCK
    SELECT
        'opex' AS source,
        DATE_TRUNC(o.date, MONTH) AS date,
        LOWER(o.country) AS country,
        CAST(NULL AS STRING) AS condition,
        CAST(NULL AS STRING) AS sales_channel,
        CAST(NULL AS STRING) AS currency,
        CAST(NULL AS STRING) AS billing_reason,
        CAST(NULL AS STRING) AS purchase_type,
        CAST(NULL AS STRING) AS new_existing,
        CAST(NULL AS STRING) AS customer_id,
        0.0 AS amount,
        0.0 AS cogs,
        0.0 AS packaging,
        0.0 AS cashback,
        0.0 AS tax_paid_usd,
        0.0 AS gateway_fees,
        0.0 AS refunds,
        0 AS n_orders,
        0.0 AS marketing_cost,
        0.0 AS delivery_cost,
        -SUM(o.dispensing_fees / fx.fx_to_usd) AS dispensing_fees,
        -SUM(o.operating_expense / fx.fx_to_usd) AS operating_expense,
        -SUM(o.staff_cost / fx.fx_to_usd) AS staff_cost
    FROM google_sheets.opex o
    JOIN ref.fx_rates AS fx ON LOWER(o.currency) = fx.currency
    GROUP BY 1,2,3
    
    UNION ALL
    -- TELECONSULTATION FEES AS COGS BLOCK
	SELECT
	  'teleconsult_cogs' AS source,
	  DATE_TRUNC(o.date, MONTH) AS date,
	  LOWER(o.country) AS country,
	  'Services' AS condition,  -- explicitly assign the condition!
	  CAST(NULL AS STRING) AS sales_channel,
	  CAST(NULL AS STRING) AS currency,
	  CAST(NULL AS STRING) AS billing_reason,
	  CAST(NULL AS STRING) AS purchase_type,
	  CAST(NULL AS STRING) AS new_existing,
	  CAST(NULL AS STRING) AS customer_id,
	  0.0 AS amount,
	  -SUM(o.teleconsultation_fees / fx.fx_to_usd) AS cogs,  -- use as cogs, negative if that's your convention
	  0.0 AS packaging,
	  0.0 AS cashback,
	  0.0 AS tax_paid_usd,
	  0.0 AS gateway_fees,
	  0.0 AS refunds,
	  0 AS n_orders,
	  0.0 AS marketing_cost,
	  0.0 AS delivery_cost,
	  0.0 AS dispensing_fees,
	  0.0 AS operating_expense,
	  0.0 AS staff_cost
	FROM google_sheets.opex o
	JOIN ref.fx_rates AS fx 
		ON LOWER(o.currency) = fx.currency
	GROUP BY 1,2,3,4
)

SELECT
  -- All grouping columns:
  source,
  date,
  country,
  condition,
  sales_channel,
  currency,
  billing_reason,
  purchase_type,
  new_existing,
  customer_id,

  -- All value columns:
  amount,
  cogs,
  packaging,
  cashback,
  tax_paid_usd,
  gateway_fees,
  refunds,
  n_orders,
  marketing_cost,
  delivery_cost,
  dispensing_fees,
  operating_expense,
  staff_cost,

  -- Margin calculations
  amount AS gross_revenue,
  amount - refunds - tax_paid_usd AS net_revenue,
  amount - refunds - tax_paid_usd - cogs - dispensing_fees AS gross_profit,
  amount - refunds - tax_paid_usd - cogs - dispensing_fees - packaging - delivery_cost - gateway_fees AS cm2,
  amount - refunds - tax_paid_usd - cogs - dispensing_fees - packaging - delivery_cost - gateway_fees - marketing_cost AS cm3,
  amount - refunds - tax_paid_usd - cogs - dispensing_fees - packaging - delivery_cost - gateway_fees - marketing_cost - operating_expense - staff_cost AS ebitda

FROM blocks
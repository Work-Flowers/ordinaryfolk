DROP VIEW IF EXISTS finance_metrics.monthly_contribution_margin;
CREATE VIEW finance_metrics.monthly_contribution_margin AS

WITH

-- ------------------ Source Aggregations ------------------
raw_data AS (
  SELECT
    COALESCE(LOWER(region), 'N/A') AS country,
    DATE_TRUNC(purchase_date, MONTH) AS date,
    COALESCE(condition, 'N/A') AS condition,
    currency,
    sales_channel,
    COALESCE(line_item_amount_usd, total_charge_amount_usd) AS amount,
    cogs * quantity AS cogs,
    packaging,
    cashback,
    amount_refunded_usd,
    fee_rate,
    gst_vat,
    charge_id
  FROM finance_metrics.contribution_margin
),

sales_agg AS (
  SELECT
    date,
    country,
    condition,
    currency,
    sales_channel,
    SUM(amount) AS amount,
    SUM(COALESCE(cogs, 0) * (1 - SAFE_DIVIDE(amount_refunded_usd, amount))) AS cogs,
    SUM(packaging) AS packaging,
    SUM(cashback) AS cashback,
    SUM((amount - amount_refunded_usd) * (1 - 1 / (1 + gst_vat))) AS tax_paid_usd,
    SUM(amount * fee_rate) AS gateway_fees,
    SUM(amount_refunded_usd) AS refunds,
    COUNT(DISTINCT charge_id) AS n_orders
  FROM raw_data
  GROUP BY 1,2,3,4,5
),

marketing_agg AS (
  SELECT
    DATE_TRUNC(date, MONTH) AS date,
    COALESCE(LOWER(country_code), 'N/A') AS country,
    COALESCE(condition, 'N/A') AS condition,
    SUM(cost_usd) AS marketing_cost
  FROM cac.marketing_spend
  GROUP BY 1,2,3
),

delivery_agg AS (
  SELECT
    DATE_TRUNC(dc.date, MONTH) AS date,
    COALESCE(LOWER(dc.country), 'N/A') AS country,
    'N/A' AS condition,
    SUM(dc.cost / fx.fx_to_usd) AS delivery_cost
  FROM google_sheets.delivery_cost dc
  JOIN ref.fx_rates AS fx ON LOWER(dc.currency) = fx.currency
  GROUP BY 1,2,3
),

opex_agg AS (
  SELECT
    DATE_TRUNC(o.date, MONTH) AS date,
    COALESCE(LOWER(o.country), 'N/A') AS country,
    'N/A' AS condition,
    -SUM(o.teleconsultation_fees / fx.fx_to_usd) AS teleconsultation_fees,
    -SUM(o.dispensing_fees / fx.fx_to_usd) AS dispensing_fees,
    -SUM(o.operating_expense / fx.fx_to_usd) AS operating_expense,
    -SUM(o.staff_cost / fx.fx_to_usd) AS staff_cost
  FROM google_sheets.opex o
  JOIN ref.fx_rates AS fx ON LOWER(o.currency) = fx.currency
  GROUP BY 1,2,3
),

-- ------------------ All Keys Scaffold ------------------
all_keys AS (
  SELECT DISTINCT
    date, country, condition, currency, sales_channel
  FROM sales_agg
  UNION DISTINCT
  SELECT DISTINCT
    date, country, condition, CAST(NULL AS STRING) AS currency, CAST(NULL AS STRING) AS sales_channel
  FROM marketing_agg
  UNION DISTINCT
  SELECT DISTINCT
    date, country, condition, CAST(NULL AS STRING) AS currency, CAST(NULL AS STRING) AS sales_channel
  FROM delivery_agg
  UNION DISTINCT
  SELECT DISTINCT
    date, country, condition, CAST(NULL AS STRING) AS currency, CAST(NULL AS STRING) AS sales_channel
  FROM opex_agg
),

-- ------------------ Join Sales to All Keys ------------------
all_sales AS (
  SELECT
    k.date,
    k.country,
    k.condition,
    COALESCE(k.currency, s.currency) AS currency,
    COALESCE(k.sales_channel, s.sales_channel) AS sales_channel,
    COALESCE(s.amount, 0) AS amount,
    COALESCE(s.cogs, 0) AS cogs,
    COALESCE(s.packaging, 0) AS packaging,
    COALESCE(s.cashback, 0) AS cashback,
    COALESCE(s.tax_paid_usd, 0) AS tax_paid_usd,
    COALESCE(s.gateway_fees, 0) AS gateway_fees,
    COALESCE(s.refunds, 0) AS refunds,
    COALESCE(s.n_orders, 0) AS n_orders
  FROM all_keys k
  LEFT JOIN sales_agg s
    ON k.date = s.date AND k.country = s.country AND k.condition = s.condition
      AND (k.currency = s.currency OR (k.currency IS NULL AND s.currency IS NULL))
      AND (k.sales_channel = s.sales_channel OR (k.sales_channel IS NULL AND s.sales_channel IS NULL))
),

-- ------------------ Calculate Total Sales Per Prorate Group ------------------
total_sales_per_key AS (
  SELECT
    date, country, condition,
    SUM(amount) AS total_amount
  FROM all_sales
  GROUP BY 1,2,3
),

-- ------------------ Calculate Revenue Share for Each Row ------------------
all_sales_with_share AS (
  SELECT
    s.*,
    t.total_amount,
    CASE
      WHEN t.total_amount = 0 THEN 0
      ELSE SAFE_DIVIDE(s.amount, t.total_amount)
    END AS channel_share
  FROM all_sales s
  LEFT JOIN total_sales_per_key t
    ON s.date = t.date AND s.country = t.country AND s.condition = t.condition
),

-- ------------------ Prorate All Costs to All Keys ------------------
all_costs_prorated AS (
  SELECT
    s.date,
    s.country,
    s.condition,
    s.currency,
    s.sales_channel,

    s.amount,
    s.cogs,
    s.packaging,
    s.cashback,
    s.tax_paid_usd,
    s.gateway_fees,
    s.refunds,
    s.n_orders,

    COALESCE(d.delivery_cost, 0) * s.channel_share AS delivery_cost,
    COALESCE(m.marketing_cost, 0) * s.channel_share AS marketing_cost,
    COALESCE(o.teleconsultation_fees, 0) * s.channel_share AS teleconsultation_fees,
    COALESCE(o.dispensing_fees, 0) * s.channel_share AS dispensing_fees,
    COALESCE(o.operating_expense, 0) * s.channel_share AS operating_expense,
    COALESCE(o.staff_cost, 0) * s.channel_share AS staff_cost,

    s.channel_share
  FROM all_sales_with_share s
  LEFT JOIN marketing_agg m
    ON s.date = m.date AND s.country = m.country AND s.condition = m.condition
  LEFT JOIN delivery_agg d
    ON s.date = d.date AND s.country = d.country AND s.condition = d.condition
  LEFT JOIN opex_agg o
    ON s.date = o.date AND s.country = o.country AND s.condition = o.condition
)

-- ------------------ Final Output with Calculated Margins ------------------
SELECT
  *,
  amount AS gross_revenue,
  amount - refunds - tax_paid_usd AS net_revenue,
  amount - refunds - tax_paid_usd - cogs - dispensing_fees AS gross_profit,
  amount - refunds - tax_paid_usd - cogs - dispensing_fees
    - packaging - delivery_cost - gateway_fees AS cm2,
  amount - refunds - tax_paid_usd - cogs - dispensing_fees
    - packaging - delivery_cost - gateway_fees - marketing_cost AS cm3,
  amount - refunds - tax_paid_usd - cogs - dispensing_fees
    - packaging - delivery_cost - gateway_fees - marketing_cost
    - operating_expense - staff_cost AS ebitda
FROM all_costs_prorated

UNION ALL

-- -------- Residual rows for orphan marketing spend (when no sales in key) -------
SELECT
  m.date,
  m.country,
  m.condition,
  CAST(NULL AS STRING) AS currency,
  'UNALLOCATED' AS sales_channel,
  0 AS amount,
  0 AS cogs,
  0 AS packaging,
  0 AS cashback,
  0 AS tax_paid_usd,
  0 AS gateway_fees,
  0 AS refunds,
  0 AS n_orders,
  0 AS delivery_cost,
  m.marketing_cost AS marketing_cost,  -- 100% unallocated
  0 AS teleconsultation_fees,
  0 AS dispensing_fees,
  0 AS operating_expense,
  0 AS staff_cost,
  0 AS channel_share,
  0 AS gross_revenue,
  0 AS net_revenue,
  0 AS gross_profit,
  0 AS cm2,
  m.marketing_cost AS cm3,
  m.marketing_cost AS ebitda
FROM marketing_agg m
LEFT JOIN total_sales_per_key t
  ON m.date = t.date AND m.country = t.country AND m.condition = t.condition
WHERE COALESCE(t.total_amount, 0) = 0
;
-- Drop the view if it already exists to ensure a clean slate for re-creation
DROP VIEW IF EXISTS finance_metrics.monthly_contribution_margin;

-- Create the new view with all logic and reconciliation
CREATE VIEW finance_metrics.monthly_contribution_margin AS

WITH

-- ========================================================
-- Step 1: Source Aggregations with Standardised Keys
-- ========================================================

-- Raw transaction data: apply lowercasing and 'N/A' as default for country/condition
raw_data AS (
  SELECT
    COALESCE(LOWER(region), 'N/A') AS country,                       -- Standardise country names and fill NULLs
    DATE_TRUNC(purchase_date, MONTH) AS date,                        -- Truncate purchase date to month for reporting
    COALESCE(condition, 'N/A') AS condition,                         -- Standardise condition field, fill NULLs
    COALESCE(line_item_amount_usd, total_charge_amount_usd) AS amount,-- Fallback if line item amount is missing
    cogs * quantity AS cogs,                                         -- Calculate COGS by multiplying by quantity
    packaging,                                                       -- Packaging cost per transaction
    cashback,                                                        -- Cashback or rebate amount, if any
    amount_refunded_usd,                                             -- USD value refunded
    fee_rate,                                                        -- Gateway fee rate for this transaction
    gst_vat,                                                         -- GST/VAT percentage, if any
    charge_id                                                        -- Unique identifier for the charge
  FROM finance_metrics.contribution_margin
),

-- Aggregate sales/transactional data to monthly, country, and condition level
sales_agg AS (
  SELECT
    date,
    country,
    condition,
    SUM(amount) AS amount,   -- Total sales amount (USD)
    SUM(COALESCE(cogs, 0) * (1 - SAFE_DIVIDE(amount_refunded_usd, amount))) AS cogs, -- Net COGS after refund allocation
    SUM(packaging) AS packaging,    -- Total packaging costs
    SUM(cashback) AS cashback,      -- Total cashback issued
    SUM((amount - amount_refunded_usd) * (1 - 1 / (1 + gst_vat))) AS tax_paid_usd, -- Estimated tax paid, net of refunds
    SUM(amount * fee_rate) AS gateway_fees,   -- Sum of all gateway (payment processor) fees
    SUM(amount_refunded_usd) AS refunds,      -- Total refunded amount
    COUNT(DISTINCT charge_id) AS n_orders     -- Number of unique orders/charges
  FROM raw_data
  GROUP BY 1,2,3
),

-- Marketing spend aggregation by date, country, and condition
marketing_agg AS (
  SELECT
    DATE_TRUNC(date, MONTH) AS date,
    COALESCE(LOWER(country_code), 'N/A') AS country,    -- Standardise country and fill blanks
    COALESCE(condition, 'N/A') AS condition,            -- Standardise condition and fill blanks
    SUM(cost_usd) AS marketing_cost                     -- Total marketing spend (USD)
  FROM cac.marketing_spend
  GROUP BY 1,2,3
),

-- Delivery cost aggregated by month/country; condition always set to 'N/A'
delivery_agg AS (
  SELECT
    DATE_TRUNC(dc.date, MONTH) AS date,
    COALESCE(LOWER(dc.country), 'N/A') AS country,
    'N/A' AS condition,                              -- Delivery is not split by condition
    SUM(dc.cost / fx.fx_to_usd) AS delivery_cost     -- Convert local delivery cost to USD
  FROM google_sheets.delivery_cost dc
  JOIN ref.fx_rates AS fx ON LOWER(dc.currency) = fx.currency
  GROUP BY 1,2,3
),

-- Operating expenses aggregated by month/country; condition always set to 'N/A'
opex_agg AS (
  SELECT
    DATE_TRUNC(o.date, MONTH) AS date,
    COALESCE(LOWER(o.country), 'N/A') AS country,
    'N/A' AS condition,                                 -- OPEX is not split by condition
    -SUM(o.teleconsultation_fees / fx.fx_to_usd) AS teleconsultation_fees, -- All expenses as negatives for consistency
    -SUM(o.dispensing_fees / fx.fx_to_usd) AS dispensing_fees,
    -SUM(o.operating_expense / fx.fx_to_usd) AS operating_expense,
    -SUM(o.staff_cost / fx.fx_to_usd) AS staff_cost
  FROM google_sheets.opex o
  JOIN ref.fx_rates AS fx ON LOWER(o.currency) = fx.currency
  GROUP BY 1,2,3
),

-- ========================================================
-- Step 2: Build 'all_keys' (all valid combinations of date, country, condition)
-- This ensures that every possible reporting key is present in the output,
-- even if one or more source tables are missing a given key.
-- ========================================================
all_keys AS (
  SELECT DISTINCT date, country, condition FROM sales_agg
  UNION DISTINCT
  SELECT DISTINCT date, country, condition FROM marketing_agg
  UNION DISTINCT
  SELECT DISTINCT date, country, condition FROM delivery_agg
  UNION DISTINCT
  SELECT DISTINCT date, country, condition FROM opex_agg
)

-- ========================================================
-- Step 3: Final Output - LEFT JOIN all sources to all_keys
-- Ensures complete coverage and alignment, prevents accidental dropping of
-- orphan rows from any source.
-- ========================================================
SELECT
  k.date,
  k.country,
  k.condition,

  -- Base metrics from sales
  COALESCE(s.amount, 0) AS amount,
  COALESCE(s.cogs, 0) AS cogs,
  COALESCE(s.packaging, 0) AS packaging,
  COALESCE(s.cashback, 0) AS cashback,
  COALESCE(s.tax_paid_usd, 0) AS tax_paid_usd,
  COALESCE(s.gateway_fees, 0) AS gateway_fees,
  COALESCE(s.refunds, 0) AS refunds,
  COALESCE(s.n_orders, 0) AS n_orders,

  -- Cost lines from other sources
  COALESCE(d.delivery_cost, 0) AS delivery_cost,
  COALESCE(m.marketing_cost, 0) AS marketing_cost,
  COALESCE(o.teleconsultation_fees, 0) AS teleconsultation_fees,
  COALESCE(o.dispensing_fees, 0) AS dispensing_fees,
  COALESCE(o.operating_expense, 0) AS operating_expense,
  COALESCE(o.staff_cost, 0) AS staff_cost,

  -- Derived margin calculations
  COALESCE(s.amount, 0) AS gross_revenue,
  -- Net revenue: revenue net of refunds and tax
  COALESCE(s.amount, 0) - COALESCE(s.refunds, 0) - COALESCE(s.tax_paid_usd, 0) AS net_revenue,
  -- Gross profit: net revenue minus COGS and dispensing
  COALESCE(s.amount, 0) - COALESCE(s.refunds, 0) - COALESCE(s.tax_paid_usd, 0)
    - COALESCE(s.cogs, 0) - COALESCE(o.dispensing_fees, 0) AS gross_profit,
  -- Contribution Margin 2 (CM2): after gross profit, subtract packaging, delivery, gateway
  COALESCE(s.amount, 0) - COALESCE(s.refunds, 0) - COALESCE(s.tax_paid_usd, 0)
    - COALESCE(s.cogs, 0) - COALESCE(o.dispensing_fees, 0)
    - COALESCE(s.packaging, 0) - COALESCE(d.delivery_cost, 0) - COALESCE(s.gateway_fees, 0) AS cm2,
  -- Contribution Margin 3 (CM3): CM2 minus marketing cost
  COALESCE(s.amount, 0) - COALESCE(s.refunds, 0) - COALESCE(s.tax_paid_usd, 0)
    - COALESCE(s.cogs, 0) - COALESCE(o.dispensing_fees, 0)
    - COALESCE(s.packaging, 0) - COALESCE(d.delivery_cost, 0) - COALESCE(s.gateway_fees, 0)
    - COALESCE(m.marketing_cost, 0) AS cm3,
  -- EBITDA: CM3 minus all OPEX
  COALESCE(s.amount, 0) - COALESCE(s.refunds, 0) - COALESCE(s.tax_paid_usd, 0)
    - COALESCE(s.cogs, 0) - COALESCE(o.dispensing_fees, 0)
    - COALESCE(s.packaging, 0) - COALESCE(d.delivery_cost, 0) - COALESCE(s.gateway_fees, 0)
    - COALESCE(m.marketing_cost, 0)
    - COALESCE(o.operating_expense, 0)
    - COALESCE(o.staff_cost, 0) AS ebitda

FROM all_keys AS k
LEFT JOIN sales_agg AS s 
	ON k.date = s.date 
	AND k.country = s.country 
	AND k.condition = s.condition
LEFT JOIN marketing_agg AS m 
	ON k.date = m.date 
	AND k.country = m.country 
	AND k.condition = m.condition
LEFT JOIN delivery_agg AS d 
	ON k.date = d.date 
	AND k.country = d.country 
	AND k.condition = d.condition
LEFT JOIN opex_agg AS o 
	ON k.date = o.date 
 	AND k.country = o.country 
 	AND k.condition = o.condition
;
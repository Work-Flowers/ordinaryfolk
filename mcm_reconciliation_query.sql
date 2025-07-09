-- 8 July 2025 10:22:28
WITH
-- Source marketing
source_marketing AS (
  SELECT DATE_TRUNC(date, MONTH) AS date, ROUND(SUM(cost_usd),2) AS marketing_source_total
  FROM cac.marketing_spend
  GROUP BY 1
),
-- Source delivery
source_delivery AS (
  SELECT DATE_TRUNC(dc.date, MONTH) AS date, ROUND(SUM(dc.cost / fx.fx_to_usd),2) AS delivery_source_total
  FROM google_sheets.delivery_cost dc
  JOIN ref.fx_rates AS fx ON LOWER(dc.currency) = fx.currency
  GROUP BY 1
),
-- Source opex: teleconsultation_fees
source_teleconsult AS (
  SELECT DATE_TRUNC(o.date, MONTH) AS date, ROUND(SUM(-o.teleconsultation_fees / fx.fx_to_usd),2) AS teleconsult_source_total
  FROM google_sheets.opex o
  JOIN ref.fx_rates AS fx ON LOWER(o.currency) = fx.currency
  GROUP BY 1
),
source_dispensing AS (
  SELECT DATE_TRUNC(o.date, MONTH) AS date, ROUND(SUM(-o.dispensing_fees / fx.fx_to_usd),2) AS dispensing_source_total
  FROM google_sheets.opex o
  JOIN ref.fx_rates AS fx ON LOWER(o.currency) = fx.currency
  GROUP BY 1
),
source_operating AS (
  SELECT DATE_TRUNC(o.date, MONTH) AS date, ROUND(SUM(-o.operating_expense / fx.fx_to_usd),2) AS operating_source_total
  FROM google_sheets.opex o
  JOIN ref.fx_rates AS fx ON LOWER(o.currency) = fx.currency
  GROUP BY 1
),
source_staff AS (
  SELECT DATE_TRUNC(o.date, MONTH) AS date, ROUND(SUM(-o.staff_cost / fx.fx_to_usd),2) AS staff_source_total
  FROM google_sheets.opex o
  JOIN ref.fx_rates AS fx ON LOWER(o.currency) = fx.currency
  GROUP BY 1
),

-- ==== REVENUE SOURCE (from original sales table) ====
source_revenue AS (
  SELECT
    DATE_TRUNC(purchase_date, MONTH) AS date,
    ROUND(SUM(COALESCE(line_item_amount_usd, total_charge_amount_usd)), 2) AS revenue_source_total
  FROM finance_metrics.contribution_margin
  GROUP BY 1
),

-- ==== REVENUE FROM THE VIEW ====
view_totals AS (
  SELECT
    date,
    ROUND(SUM(marketing_cost),2) AS marketing_view_total,
    ROUND(SUM(delivery_cost),2) AS delivery_view_total,
    ROUND(SUM(dispensing_fees),2) AS dispensing_view_total,
    ROUND(SUM(operating_expense),2) AS operating_view_total,
    ROUND(SUM(staff_cost),2) AS staff_view_total,
    ROUND(SUM(gross_revenue),2) AS revenue_view_total
  FROM finance_metrics.monthly_contribution_margin
  GROUP BY 1
)

SELECT
  COALESCE(vm.date, vd.date, vt.date, vs.date, vo.date, vss.date, sr.date) AS date,

  -- REVENUE
  ROUND(sr.revenue_source_total - vt.revenue_view_total, 2) AS revenue_difference,
  ROUND(SAFE_DIVIDE(sr.revenue_source_total, vt.revenue_view_total) - 1, 4) AS revenue_pct_difference,

  -- MARKETING
  ROUND(vm.marketing_source_total - vt.marketing_view_total, 2) AS marketing_difference,
  ROUND(SAFE_DIVIDE(vm.marketing_source_total, vt.marketing_view_total) - 1, 4) AS marketing_pct_difference,

  -- DELIVERY
  ROUND(vd.delivery_source_total - vt.delivery_view_total, 2) AS delivery_difference,
  ROUND(SAFE_DIVIDE(vd.delivery_source_total, vt.delivery_view_total) - 1, 4) AS delivery_pct_difference,


  -- DISPENSING
  ROUND(vs.dispensing_source_total - vt.dispensing_view_total, 2) AS dispensing_difference,
  ROUND(SAFE_DIVIDE(vs.dispensing_source_total, vt.dispensing_view_total) - 1, 4) AS dispensing_pct_difference,

  -- OPERATING
  ROUND(vo.operating_source_total - vt.operating_view_total, 2) AS operating_difference,
  ROUND(SAFE_DIVIDE(vo.operating_source_total, vt.operating_view_total) - 1, 4) AS operating_pct_difference,

  -- STAFF
  ROUND(vss.staff_source_total - vt.staff_view_total, 2) AS staff_difference,
  ROUND(SAFE_DIVIDE(vss.staff_source_total, vt.staff_view_total) - 1, 4) AS staff_pct_difference

FROM view_totals vt
LEFT JOIN source_marketing vm ON vt.date = vm.date
LEFT JOIN source_delivery vd ON vt.date = vd.date
LEFT JOIN source_dispensing vs ON vt.date = vs.date
LEFT JOIN source_operating vo ON vt.date = vo.date
LEFT JOIN source_staff vss ON vt.date = vss.date
LEFT JOIN source_revenue sr ON vt.date = sr.date

ORDER BY 1 DESC
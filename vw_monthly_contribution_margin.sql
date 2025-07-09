DROP VIEW IF EXISTS finance_metrics.monthly_contribution_margin;

CREATE VIEW finance_metrics.monthly_contribution_margin AS
WITH
	-- Source data extraction and aggregation (same as before)
	raw_data AS (
		SELECT
			COALESCE(LOWER(region), 'N/A') AS country,
			DATE_TRUNC(purchase_date, MONTH) AS DATE,
			COALESCE(condition, 'N/A') AS condition,
			COALESCE(line_item_amount_usd, total_charge_amount_usd) AS amount,
			cogs * quantity AS cogs,
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
	sales_agg AS (
		SELECT
			DATE,
			country,
			condition,
			sales_channel,
			currency,
			billing_reason AS billing_reason,
			purchase_type AS purchase_type,
			new_existing AS new_existing,
			customer_id AS customer_id,
			SUM(amount) AS amount,
			SUM(COALESCE(cogs, 0) * (1 - SAFE_DIVIDE(amount_refunded_usd, amount))) AS cogs,
			SUM(packaging) AS packaging,
			SUM(cashback) AS cashback,
			SUM((amount - amount_refunded_usd) * (1 - 1 / (1 + gst_vat))) AS tax_paid_usd,
			SUM(amount * fee_rate) AS gateway_fees,
			SUM(amount_refunded_usd) AS refunds,
			COUNT(DISTINCT charge_id) AS n_orders
		FROM raw_data
		GROUP BY 1,2,3,4,5,6,7,8,9
	),
	marketing_agg AS (
		SELECT
			DATE_TRUNC(DATE, MONTH) AS DATE,
			COALESCE(LOWER(country_code), 'N/A') AS country,
			COALESCE(condition, 'N/A') AS condition,
			SUM(cost_usd) AS marketing_cost
		FROM cac.marketing_spend
		GROUP BY 1,2,3
	),
	delivery_agg AS (
		SELECT
			DATE_TRUNC(dc.date, MONTH) AS DATE,
			COALESCE(LOWER(dc.country), 'N/A') AS country,
			'N/A' AS condition,
			SUM(dc.cost / fx.fx_to_usd) AS delivery_cost
		FROM google_sheets.delivery_cost dc
		JOIN ref.fx_rates AS fx 
			ON LOWER(dc.currency) = fx.currency
		GROUP BY 1,2,3
	),
	opex_agg AS (
		SELECT
			DATE_TRUNC(o.date, MONTH) AS DATE,
			COALESCE(LOWER(o.country), 'N/A') AS country,
			'N/A' AS condition,
			- SUM(o.teleconsultation_fees / fx.fx_to_usd) AS teleconsultation_fees,
			- SUM(o.dispensing_fees / fx.fx_to_usd) AS dispensing_fees,
			- SUM(o.operating_expense / fx.fx_to_usd) AS operating_expense,
			- SUM(o.staff_cost / fx.fx_to_usd) AS staff_cost
		FROM google_sheets.opex o
		JOIN ref.fx_rates AS fx 
			ON LOWER(o.currency) = fx.currency
		GROUP BY 1,2,3
	),
	sales_totals AS (
		SELECT
			DATE,
			country,
			condition,
			SUM(amount) AS total_amount
		FROM sales_agg
		GROUP BY 1,2,3
	),
	sales_with_share AS (
		SELECT
			s.*,
			st.total_amount,
			SAFE_DIVIDE(s.amount, st.total_amount) AS channel_share
		FROM sales_agg AS s
		LEFT JOIN sales_totals AS st 
			ON s.date = st.date
			AND s.country = st.country
			AND s.condition = st.condition
	),
	all_keys AS (
		SELECT DISTINCT
			DATE,
			country,
			condition
		FROM sales_agg
		
		UNION DISTINCT
		
		SELECT DISTINCT
			DATE,
			country,
			condition
		FROM marketing_agg
		
		UNION DISTINCT
		
		SELECT DISTINCT
			DATE,
			country,
			condition
		FROM delivery_agg
		
		UNION DISTINCT
		
		SELECT DISTINCT
			DATE,
			country,
			condition
		FROM opex_agg
	),
	-- ==================================================
	-- CTE: Base table with all calculated building blocks
	-- ==================================================
	base AS (
		SELECT
			k.date,
			k.country,
			k.condition,
			sws.sales_channel,
			sws.currency,
			sws.billing_reason,
			sws.purchase_type,
			sws.new_existing,
			sws.customer_id,
			COALESCE(sws.amount, 0) AS amount,
			-- "Adjusted" COGS: swap for teleconsultation_fees when condition = 'Services'
			CASE
				WHEN k.condition = 'Services' THEN COALESCE(o.teleconsultation_fees, 0) * COALESCE(sws.channel_share, 1)
				ELSE COALESCE(sws.cogs, 0)
			END AS cogs,
			COALESCE(sws.packaging, 0) AS packaging,
			COALESCE(sws.cashback, 0) AS cashback,
			COALESCE(sws.tax_paid_usd, 0) AS tax_paid_usd,
			COALESCE(sws.gateway_fees, 0) AS gateway_fees,
			COALESCE(sws.refunds, 0) AS refunds,
			COALESCE(sws.n_orders, 0) AS n_orders,
			COALESCE(d.delivery_cost, 0) * COALESCE(sws.channel_share, 1) AS delivery_cost,
			COALESCE(m.marketing_cost, 0) * COALESCE(sws.channel_share, 1) AS marketing_cost,
			COALESCE(o.teleconsultation_fees, 0) * COALESCE(sws.channel_share, 1) AS teleconsultation_fees,
			COALESCE(o.dispensing_fees, 0) * COALESCE(sws.channel_share, 1) AS dispensing_fees,
			COALESCE(o.operating_expense, 0) * COALESCE(sws.channel_share, 1) AS operating_expense,
			COALESCE(o.staff_cost, 0) * COALESCE(sws.channel_share, 1) AS staff_cost
		FROM all_keys AS k
		LEFT JOIN sales_with_share AS sws 
			ON k.date = sws.date
			AND k.country = sws.country
			AND k.condition = sws.condition
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
	)
	-- =============================================
	-- Final SELECT with all margin calculations
	-- =============================================
SELECT
	base.* EXCEPT (amount),
	amount AS gross_revenue,
	amount - refunds - tax_paid_usd AS net_revenue,
	amount - refunds - tax_paid_usd - cogs - dispensing_fees AS gross_profit,
	amount - refunds - tax_paid_usd - cogs - dispensing_fees - packaging - delivery_cost - gateway_fees AS cm2,
	amount - refunds - tax_paid_usd - cogs - dispensing_fees - packaging - delivery_cost - gateway_fees - marketing_cost AS cm3,
	amount - refunds - tax_paid_usd - cogs - dispensing_fees - packaging - delivery_cost - gateway_fees - marketing_cost - operating_expense - staff_cost AS ebitda
FROM base;
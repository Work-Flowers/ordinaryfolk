-- Drop the existing view if it exists
DROP VIEW IF EXISTS `all_stripe.subscription_metrics`;

-- Create the view
CREATE VIEW `all_stripe.subscription_metrics` AS

WITH 
-- 1) Use a window function to get only the *latest* row per subscription
sub_active_slices AS (
	SELECT
		region,
		id AS subscription_id,
		customer_id,
		status,
		CAST(created AS DATE) AS created_at,
		CAST(COALESCE(ended_at, _fivetran_end) AS DATE) AS ended_at
	FROM (
		SELECT
			region,
			id,
			customer_id,
			status,
			created,
			_fivetran_end,
			ended_at,
			ROW_NUMBER() OVER (
				PARTITION BY id
				ORDER BY _fivetran_end DESC
			) AS row_num
		FROM all_stripe.subscription_history
	)
	WHERE row_num = 1
),

-- 2) Calculate "MRR" per subscription_id, grouping by currency
sub_mrr AS (
	SELECT
		si.subscription_id,
		pl.currency,
		pl.id AS plan_id,
		pl.product_id,
		CASE 
			WHEN pl.interval = 'month' THEN pl.amount * si.quantity / 100 / COALESCE(pl.interval_count, 1)
			WHEN pl.interval = 'year' THEN pl.amount * si.quantity / 100 / (12 * COALESCE(pl.interval_count, 1))
			WHEN pl.interval = 'week' THEN pl.amount * si.quantity / 100 * (52/ 12) / COALESCE(pl.interval_count, 1)
			WHEN pl.interval = 'day' THEN pl.amount * si.quantity / 100 * (365 / 12)/ COALESCE(pl.interval_count, 1)
			ELSE 0
			END AS subscription_mrr
	FROM all_stripe.subscription_item AS si
	JOIN all_stripe.plan AS pl
		ON si.plan_id = pl.id
),

-- 3) Attach MRR + currency to each subscription slice
active_slices_with_mrr AS (
	SELECT
		sas.region,
		sas.subscription_id,
		sas.customer_id,
		sas.status,
		sas.created_at,
		sas.ended_at,
		COALESCE(sm.subscription_mrr, 0) AS mrr_local,
		COALESCE(sm.subscription_mrr, 0) / fx.fx_to_usd AS mrr_usd,
		sm.currency,
		sm.plan_id,
		sm.product_id
	FROM sub_active_slices AS sas
	LEFT JOIN sub_mrr AS sm
		ON sas.subscription_id = sm.subscription_id
	LEFT JOIN ref.fx_rates AS fx
		ON sm.currency = fx.currency
),

-- 4) Build a monthly calendar from 2020-08-01 to current date
monthly_calendar AS (
	SELECT
		month_start
	FROM UNNEST(
		GENERATE_DATE_ARRAY(
			DATE '2020-08-01',
		CURRENT_DATE(),
		INTERVAL 1 MONTH
		)
	) AS month_start
),

-- 5) Last successful charge date for canceled subscriptions
last_payment AS (
	SELECT
		sas.subscription_id,
		CAST(MAX(DATE_TRUNC(c.created, MONTH)) AS DATE) AS last_paid
	FROM sub_active_slices AS sas
	JOIN all_stripe.invoice AS i
		ON sas.subscription_id = i.subscription_id 
	JOIN all_stripe.charge AS c
		ON i.id = c.invoice_id
		AND c.status = 'succeeded'
	GROUP BY 1
)

-- 6) Final SELECT
SELECT
	aswm.region,
	aswm.subscription_id,
	aswm.customer_id,
	mc.month_start,
	aswm.created_at,
	COALESCE(lp.last_paid, aswm.ended_at) AS ended_at,
	aswm.currency,
	aswm.plan_id,
	aswm.product_id,
	-- If subscription was active, return MRR; else 0
	CASE
		WHEN aswm.ended_at >= mc.month_start THEN aswm.mrr_local
		ELSE 0
		END AS mrr_local,
	CASE
		WHEN COALESCE(lp.last_paid, aswm.ended_at) >= mc.month_start THEN aswm.mrr_usd
		ELSE 0
		END AS mrr_usd
FROM active_slices_with_mrr AS aswm
LEFT JOIN last_payment AS lp
	ON aswm.subscription_id = lp.subscription_id
	AND aswm.status = 'canceled'
LEFT JOIN monthly_calendar AS mc
	ON aswm.created_at <= LAST_DAY(mc.month_start)
	AND COALESCE(lp.last_paid, aswm.ended_at) >= DATE_ADD(mc.month_start, INTERVAL -1 MONTH)


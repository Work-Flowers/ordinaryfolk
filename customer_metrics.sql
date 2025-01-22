-- Drop the existing view if it exists
DROP VIEW IF EXISTS `all_stripe.customer_metrics`;

-- Create the view
CREATE VIEW `all_stripe.customer_metrics` AS

WITH 
-- 1) Use a window function to get only the *latest* row per subscription
sub_active_slices AS (
	SELECT
		region,
		id AS subscription_id,
		customer_id,
		status,
		DATE(created) AS created_at,
		DATE(COALESCE(ended_at, _fivetran_end)) AS ended_at
	FROM all_stripe.subscription_history
	QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _fivetran_end DESC) = 1
),

-- 2) Calculate "MRR" per subscription_id, grouping by currency
sub_mrr AS (
	SELECT
		si.subscription_id,
		pl.currency,
		pl.id AS plan_id,
		pl.interval,
		pl.interval_count,
		pl.product_id,
		CASE 
			WHEN pl.interval = 'month' THEN pl.amount * si.quantity / 100 / COALESCE(pl.interval_count, 1)
			WHEN pl.interval = 'year' THEN pl.amount * si.quantity / 100 / (12 * COALESCE(pl.interval_count, 1))
			WHEN pl.interval = 'week' THEN pl.amount * si.quantity / 100 * (52/ 12) / COALESCE(pl.interval_count, 1)
			WHEN pl.interval = 'day' THEN pl.amount * si.quantity / 100 * (365 / 12)/ COALESCE(pl.interval_count, 1)
			ELSE 0
			END AS subscription_mrr,
		JSON_EXTRACT_SCALAR(pl.metadata, '$.boxes') AS n_boxes,
		prod.name AS product_name,
		COALESCE(JSON_EXTRACT_SCALAR(prod.metadata, '$.condition'), 'Other') AS condition
	FROM all_stripe.subscription_item AS si
	JOIN all_stripe.plan AS pl
		ON si.plan_id = pl.id
	LEFT JOIN all_stripe.product AS prod
		ON pl.product_id = prod.id
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
		sm.interval,
		sm.interval_count,
		sm.product_id,
		sm.n_boxes,
		sm.product_name,
		sm.condition
	FROM sub_active_slices AS sas
	LEFT JOIN sub_mrr AS sm
		ON sas.subscription_id = sm.subscription_id
	LEFT JOIN ref.fx_rates AS fx
		ON sm.currency = fx.currency
		
),

-- 4) Build a monthly calendar from 2020-08-01 to current date
calendar AS (
	SELECT
		obs_date
	FROM UNNEST(
		GENERATE_DATE_ARRAY(
			DATE '2020-08-01',
		CURRENT_DATE(),
		INTERVAL 1 DAY
		)
	) AS obs_date
),

-- 5) Last successful charge date for canceled subscriptions
last_payment AS (
	SELECT
		sas.subscription_id,
		CAST(MAX(c.created) AS DATE) AS last_paid
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
	aswm.customer_id,
	cal.obs_date,
	aswm.product_id,
	aswm.product_name,
	aswm.condition,
	SUM(aswm.mrr_usd) AS mrr_usd
FROM active_slices_with_mrr AS aswm
LEFT JOIN last_payment AS lp
	ON aswm.subscription_id = lp.subscription_id
	AND aswm.status = 'canceled'
INNER JOIN calendar AS cal
	ON aswm.created_at <= cal.obs_date
	AND COALESCE(lp.last_paid, aswm.ended_at) >= cal.obs_date
GROUP BY 1,2,3,4,5,6
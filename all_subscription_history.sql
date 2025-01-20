-- Drop the existing view if it exists
DROP VIEW IF EXISTS `all_stripe.subscription_history`;

-- Create the view
CREATE VIEW `all_stripe.subscription_history` AS

WITH
-- 1) Gather slices from all regions, capturing _fivetran_start, _fivetran_end, and ended_at
sub_active_slices AS (
	SELECT 
		region,
		subscription_id,
		customer_id,
		status,
		created_at,
		ended_at
	FROM(
		SELECT
			'sg' AS region,
			id AS subscription_id,
			customer_id,
			status,
			CAST(created AS DATE) AS created_at,
			CAST(COALESCE(ended_at, _fivetran_end) AS DATE) AS ended_at,
			ROW_NUMBER() OVER (
				PARTITION BY id
	            ORDER BY _fivetran_end DESC
			) AS row_num
		FROM `sg_stripe.subscription_history`
		UNION ALL
		SELECT
			'hk' AS region,
			id AS subscription_id,
			customer_id,
			status,
			CAST(created AS DATE) AS created_at,
			CAST(COALESCE(ended_at, _fivetran_end) AS DATE) AS ended_at,
			ROW_NUMBER() OVER (
				PARTITION BY id
	            ORDER BY _fivetran_end DESC
			) AS row_num
		FROM `hk_stripe.subscription_history`
		UNION ALL
		SELECT
			'jp' AS region,
			id AS subscription_id,
			customer_id,
			status,
			CAST(created AS DATE) AS created_at,
			CAST(COALESCE(ended_at, _fivetran_end) AS DATE) AS ended_at,
			ROW_NUMBER() OVER (
				PARTITION BY id
	            ORDER BY _fivetran_end DESC
			) AS row_num
		FROM `jp_stripe.subscription_history`
	) AS a
	WHERE a.row_num = 1
  ),
  
-- 2) Calculate "MRR" per subscription by joining subscription_items to plan, grouping by (subscription_id, currency)
sub_mrr AS (
    SELECT
        si.subscription_id,
        pl.currency,
        SUM(
            CASE
            -- For monthly plans, simply divide by interval_count if > 1 (e.g., billed every N months).
            WHEN pl.interval = 'month' THEN (pl.amount * si.quantity / 100) / COALESCE(pl.interval_count, 1)
            
            -- For yearly plans, divide by 12 * interval_count to get the monthly portion.
            WHEN pl.interval = 'year' THEN (pl.amount * si.quantity / 100) / (12 * COALESCE(pl.interval_count, 1))
            
            -- Weekly → monthly. Approximately 52 weeks per year, so 52/12 ≈ 4.333 weeks per month.
            WHEN pl.interval = 'week' THEN (pl.amount * si.quantity / 100) * (52 / 12) / COALESCE(pl.interval_count, 1)
            
            -- Daily → monthly. Approx. 365 days/year, so 365/12 ≈ 30.4167 days per month.
            WHEN pl.interval = 'day' THEN (pl.amount * si.quantity / 100) * (365 / 12) / COALESCE(pl.interval_count, 1) 
            ELSE 0
            END
        ) AS subscription_mrr
    FROM (
        SELECT
            subscription_id,
            plan_id,
            quantity
        FROM `sg_stripe.subscription_item`
        UNION ALL
        SELECT
            subscription_id,
            plan_id,
            quantity
        FROM `hk_stripe.subscription_item`
        UNION ALL
        SELECT
            subscription_id,
            plan_id,
            quantity
        FROM `jp_stripe.subscription_item` 
    ) AS si
    
    JOIN (
        SELECT
            id AS plan_id,
            amount,
            s.interval,
            interval_count,
            currency
        FROM `sg_stripe.plan` AS s
        UNION ALL
        SELECT
            id AS plan_id,
            amount,
            h.interval,
            interval_count,
            currency
        FROM `hk_stripe.plan` AS h
        UNION ALL
		SELECT
			id AS plan_id,
            amount,
            j.interval,
            interval_count,
            currency
        FROM `jp_stripe.plan` AS j 
    ) AS  pl
  ON
    si.plan_id = pl.plan_id
  GROUP BY
    si.subscription_id,
    pl.currency 
),

-- 3) Attach the MRR + currency to each active slice
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
        -- If a subscription has items in multiple currencies, this approach only captures one currency row at a time.
        -- If that scenario occurs, you may get multiple rows per subscription_id for different currencies.
        sm.currency
    FROM sub_active_slices AS sas
    LEFT JOIN sub_mrr AS sm
        ON sas.subscription_id = sm.subscription_id 
	LEFT JOIN ref.fx_rates AS fx
		ON sm.currency = fx.currency
	
),

-- 4) Build a monthly calendar from 2020-01-01 to current date
monthly_calendar AS (
    SELECT
        month_start
    FROM UNNEST( GENERATE_DATE_ARRAY( DATE '2020-08-01', CURRENT_DATE(), INTERVAL 1 MONTH)) AS month_start
),

-- 5) find the last successful charge date for canceled subscriptions
last_payment AS (
	
	SELECT
		sh.id AS subscription_id,
		MAX(DATE_TRUNC(ch.created, month)) AS last_paid
	FROM sg_stripe.subscription_history AS sh
	INNER JOIN sg_stripe.invoice AS inv
		ON sh.id = inv.subscription_id
	INNER JOIN sg_stripe.charge AS ch
		ON inv.id = ch.invoice_id
		AND ch.status = 'succeeded'
	WHERE
		1 = 1
		AND sh.status = 'canceled'
	GROUP BY 1
	UNION ALL
	SELECT
		sh.id AS subscription_id,
		MAX(DATE_TRUNC(ch.created, month)) AS last_paid
	FROM hk_stripe.subscription_history AS sh
	INNER JOIN hk_stripe.invoice AS inv
		ON sh.id = inv.subscription_id
	INNER JOIN hk_stripe.charge AS ch
		ON inv.id = ch.invoice_id
		AND ch.status = 'succeeded'
	WHERE
		1 = 1
		AND sh.status = 'canceled'
	GROUP BY 1
	UNION ALL
		SELECT
		sh.id AS subscription_id,
		MAX(DATE_TRUNC(ch.created, month)) AS last_paid
	FROM jp_stripe.subscription_history AS sh
	INNER JOIN jp_stripe.invoice AS inv
		ON sh.id = inv.subscription_id
	INNER JOIN jp_stripe.charge AS ch
		ON inv.id = ch.invoice_id
		AND ch.status = 'succeeded'
	WHERE
		1 = 1
		AND sh.status = 'canceled'
	GROUP BY 1

),

-- 6) Final output
SELECT 
	aswm.region,
	aswm.subscription_id,
	aswm.customer_id,
	mc.month_start,
	aswm.created_at,
	COALESCE(lp.last_paid, aswm.ended_at) AS ended_at,
	aswm.currency,
	-- If subscription was active, return MRR; else 0
	CASE WHEN aswm.ended_at >= mc.month_start THEN aswm.mrr_local ELSE 0 END AS mrr_local,
	CASE WHEN aswm.ended_at >= mc.month_start THEN aswm.mrr_usd ELSE 0 END AS mrr_usd
FROM active_slices_with_mrr AS aswm
LEFT JOIN monthly_calendar AS mc
	ON aswm.created_at <= LAST_DAY(mc.month_start)
	AND aswm.ended_at >= DATE_ADD(COALESCE(lp.last_paid, aswm.ended_at), INTERVAL -1 MONTH)
LEFT JOIN last_payment AS lp
	ON aswm.subscription_id = lp.subscription_id
-- Drop the existing view if it exists
DROP VIEW IF EXISTS `all_stripe.subscription_history`;

-- Create the view
CREATE VIEW `all_stripe.subscription_history` AS

WITH
-- 1) Gather slices from all regions, capturing _fivetran_start, _fivetran_end, and ended_at
all_sub_slices AS (
	SELECT
		'sg' AS region,
		id AS subscription_id,
		customer_id,
		status,
		CAST(_fivetran_start AS DATE) AS scd_start,
		CAST(_fivetran_end AS DATE) AS scd_end,
		CAST(ended_at AS DATE) AS ended_at
    FROM `sg_stripe.subscription_history`

    UNION ALL

    SELECT
		'hk' AS region,
		id AS subscription_id,
		customer_id,
		status,
		CAST(_fivetran_start AS DATE) AS scd_start,
		CAST(_fivetran_end AS DATE) AS scd_end,
		CAST(ended_at AS DATE) AS ended_at
    FROM `hk_stripe.subscription_history`

    UNION ALL

    SELECT
		'jp' AS region,
		id AS subscription_id,
		customer_id,
		status,
		CAST(_fivetran_start AS DATE) AS scd_start,
		CAST(_fivetran_end AS DATE) AS scd_end,
		CAST(ended_at AS DATE) AS ended_at
    FROM `jp_stripe.subscription_history`
),

-- 2) Define the *actual* active window by combining ended_at with the SCD start/end
sub_active_slices AS (
	SELECT DISTINCT 
		region,
		subscription_id,
		customer_id,
		status,
		scd_start AS valid_start,
		COALESCE(ended_at, scd_end) AS valid_end
	FROM all_sub_slices
	WHERE status = 'active'
  ),
  
-- 3) Calculate "MRR" per subscription by joining subscription_items to plan, grouping by (subscription_id, currency)
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

-- 4) Attach the MRR + currency to each active slice
active_slices_with_mrr AS (
    SELECT
    	sas.region,    
		sas.subscription_id,
        sas.customer_id,
        sas.status,
        sas.valid_start,
        sas.valid_end,
        COALESCE(sm.subscription_mrr, 0) AS mrr,
        -- If a subscription has items in multiple currencies, this approach only captures one currency row at a time.
        -- If that scenario occurs, you may get multiple rows per subscription_id for different currencies.
        sm.currency
    FROM sub_active_slices AS sas
    LEFT JOIN sub_mrr AS sm
        ON sas.subscription_id = sm.subscription_id 
),

-- 4) Build a monthly calendar from 2021-01-01 to current date
monthly_calendar AS (
    
    SELECT
        month_start
    FROM UNNEST( GENERATE_DATE_ARRAY( DATE '2021-01-01', CURRENT_DATE(), INTERVAL 1 MONTH)) AS month_start
)

-- 5) Final output
SELECT
	aswm.region,
	aswm.subscription_id,
	aswm.customer_id,
	mc.month_start,
	-- boolean to indicate whether subscription was active in a given observation month
	(aswm.valid_start <= LAST_DAY(mc.month_start) AND aswm.valid_end >= mc.month_start) AS was_active_flag,
	-- If subscription was active, return MRR; else 0
	CASE 
	    WHEN aswm.valid_start <= LAST_DAY(mc.month_start) AND aswm.valid_end >= mc.month_start THEN aswm.mrr
	    ELSE 0 
	    END AS monthly_recurring_revenue,
	aswm.currency
FROM active_slices_with_mrr AS aswm
CROSS JOIN monthly_calendar AS mc
GROUP BY
	aswm.region,  
	aswm.subscription_id,
	aswm.customer_id,
	month_start,
	was_active_flag,
	monthly_recurring_revenue,
	aswm.currency
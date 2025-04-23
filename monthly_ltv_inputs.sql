/* ───────────────────────────
1.  Monthly MRR per customer
─────────────────────────── */
WITH monthly_obs AS (
	SELECT
		region,
		customer_id,
		CASE
			WHEN mrr_usd > 0 THEN obs_date
			WHEN obs_date = DATE_TRUNC(obs_date, MONTH) THEN obs_date
			ELSE DATE_TRUNC(DATE_ADD(obs_date, INTERVAL 1 MONTH), MONTH)
		END AS month_start,
		SUM(mrr_usd) AS mrr_usd
	FROM
		all_stripe.subscription_metrics
	WHERE
		obs_date = DATE_TRUNC(obs_date, MONTH)
		OR mrr_usd = 0
	GROUP BY 1, 2, 3
),
/* ───────────────────────────
2.  First‑month and today’s month per customer
─────────────────────────── */
customer_span AS (
	SELECT
		region,
		customer_id,
		MIN(month_start) AS first_month,
		DATE_TRUNC(CURRENT_DATE(), MONTH) AS last_month
	FROM monthly_obs
	GROUP BY 1, 2
),
/* ───────────────────────────
3.  Generate a month series for each customer
─────────────────────────── */
calendar AS (
	SELECT
		c.region,
		c.customer_id,
		m AS month_start
	FROM
		customer_span c
		CROSS JOIN UNNEST (GENERATE_DATE_ARRAY(c.first_month, c.last_month, INTERVAL 1 MONTH)) AS m
)
/* ───────────────────────────
4.  Left‑join to observed MRR;
missing rows → COALESCE to 0
─────────────────────────── */
SELECT
	cal.region,
	cal.customer_id,
	cal.month_start AS obs_date,
	COALESCE(obs.mrr_usd, 0) AS mrr_usd -- dummy rows show 0
FROM
	calendar AS cal
LEFT JOIN monthly_obs AS obs 
	ON obs.region = cal.region
	AND obs.customer_id = cal.customer_id
	AND obs.month_start = cal.month_start
	
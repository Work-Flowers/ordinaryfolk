WITH data AS (
  SELECT
    CASE 
      WHEN mrr_usd = 0 THEN DATE_ADD(LAST_DAY(obs_date), INTERVAL 1 DAY)
      ELSE obs_date
      END AS obs_date,
    customer_id,
    product_name,
    region AS country,
    condition,
    DATE_TRUNC(created_at, MONTH) AS created_month,
    SUM(mrr_usd) AS mrr
  FROM `all_stripe.subscription_metrics`
  GROUP BY 1,2,3,4,5,6
),

monthly AS (
	SELECT
		DATE_TRUNC(obs_date, MONTH) AS obs_date,
		customer_id,
		product_name,
		country,
		condition,
		MIN(MIN(created_month)) OVER (PARTITION BY customer_id) AS acq_date,
		SUM(mrr) / COUNT(DISTINCT obs_date) AS mrr
	FROM data
	GROUP BY 1,2,3,4,5
)
SELECT 
  monthly.*,
  COALESCE(
    LAG(mrr, 1) OVER(
      PARTITION BY 
        customer_id, 
        product_name, 
        country, 
        condition 
      ORDER BY obs_date
      ), 0
    ) AS mrr_lagged
FROM monthly
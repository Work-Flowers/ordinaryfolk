SELECT
  'main' AS metric_type,
  obs_date,
  customer_id,
  product_name,
  region AS country,
  condition,
  SUM(mrr_usd) AS mrr
FROM `all_stripe.subscription_metrics`
WHERE obs_date = DATE_TRUNC(obs_date, month)
GROUP BY 1,2,3,4,5,6

UNION ALL

SELECT
  'baseline' AS metric_type,
  obs_date,
  customer_id,
  product_name,
  region AS country,
  condition,
  SUM(-mrr_usd) AS mrr
FROM `all_stripe.subscription_metrics`
WHERE obs_date = DATE_TRUNC(obs_date, month)
GROUP BY 1,2,3,4,5,6
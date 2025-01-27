SELECT
  ch.region,
  ch.customer_id,
  ch.id AS charge_id,
  ch.created AS charge_created,
  ch.amount / fx.fx_to_usd / 100 AS charge_amount_usd,
  COALESCE(prod.name, 'Unknown') AS product_name,
  JSON_EXTRACT_SCALAR(prod.metadata, '$.condition') AS condition,
  SUM(COALESCE(ch.amount, ili.amount) / 100 / fx.fx_to_usd) AS total_amount_usd
FROM `all_stripe.charge` AS ch
INNER JOIN ref.fx_rates AS fx
	ON ch.currency = fx.currency
INNER JOIN all_stripe.payment_intent AS pi
	ON ch.payment_intent_id = pi.id
LEFT JOIN `all_stripe.invoice` AS inv
  ON ch.invoice_id = inv.id
 JOIN `all_stripe.invoice_line_item` AS ili
  ON inv.id = ili.invoice_id
LEFT JOIN all_stripe.price AS px
-- use price_id from invoice line item if available; otherwise look for price_id in payment_intent metadata
	ON COALESCE(ili.price_id, JSON_EXTRACT(pi.metadata, '$.paymentIntentPriceId'), JSON_EXTRACT(pi.metadata, '$.stripePriceIds')) = px.id
LEFT JOIN all_stripe.product AS prod
	ON px.product_id = prod.id
WHERE 
  ch.status = 'succeeded' -- Only successful charges
  AND (inv.subscription_id IS NULL OR inv.subscription_id = '') -- Exclude subscription-related charges
GROUP BY 1,2,3,4,5,6,7
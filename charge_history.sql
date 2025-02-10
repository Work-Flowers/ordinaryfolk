WITH monthly_charges AS (
   SELECT
		ch.created,
		ch.region,
		CASE 
			WHEN ii.subscription_id IS NULL THEN 'One-Time'
			ELSE 'Subscription'
			END AS purchase_type,
		ch.customer_id,
		prod.id AS product_id,
		prod.name AS product_name,
		JSON_EXTRACT_SCALAR(prod.metadata, '$.condition') AS condition,
		COALESCE(px.unit_amount, ch.amount) / fx.fx_to_usd / 100  AS amount,
		MIN(ch.created) OVER(PARTITION BY ch.customer_id) AS first_purchase
	FROM all_stripe.charge AS ch
	LEFT JOIN all_stripe.payment_intent AS pi
		ON ch.payment_intent_id = pi.id
	INNER JOIN ref.fx_rates AS fx
		ON ch.currency = fx.currency
	LEFT JOIN all_stripe.invoice_line_item AS ii
		ON ch.invoice_id = ii.invoice_id
	LEFT JOIN all_stripe.price AS px
	-- use price_id from invoice line item if available; otherwise look for price_id in payment_intent metadata
		ON COALESCE(ii.price_id, JSON_EXTRACT(pi.metadata, '$.paymentIntentPriceId'), JSON_EXTRACT(pi.metadata, '$.stripePriceIds')) = px.id
	LEFT JOIN all_stripe.product AS prod
		ON px.product_id = prod.id
	WHERE
		ch.status = 'succeeded'
	GROUP BY 1,2,3,4,5,6,7,8
),

months AS (
	SELECT
		created
	FROM UNNEST(
		GENERATE_DATE_ARRAY(
			DATE '2020-08-01',
		CURRENT_DATE(),
		INTERVAL 1 MONTH
		)
	) AS created
),

all_customers AS (
    SELECT DISTINCT
    	region,
    	purchase_type,
    	customer_id,
    	product_id,
    	product_name,
    	condition, 
    	first_purchase
    FROM monthly_charges
),

zero_filled_months AS (
    SELECT
        m.created,
        c.region,
        c.purchase_type,
        c.customer_id,
        c.product_id,
        c.product_name,
        c.condition,
        0.0 AS amount,
        DATE(c.first_purchase) AS first_purchase
    FROM months m
    CROSS JOIN all_customers c
),

unioned AS (
	SELECT 
		DATE(created) AS created,
		region,
		purchase_type,
		customer_id,
		product_id,
		product_name,
		condition,
		amount,
		DATE(first_purchase) AS first_purchase
	FROM monthly_charges
	
	UNION ALL
	
	SELECT *
	FROM zero_filled_months
)

SELECT
	DATE_TRUNC(created, MONTH) AS created,
	DATE_TRUNC(first_purchase, MONTH) AS first_purchase,
	region,
	purchase_type,
	customer_id,
	product_name,
	condition,
	SUM(amount) AS amount
FROM unioned
WHERE DATE_TRUNC(created, MONTH) >= DATE_TRUNC(first_purchase, MONTH)
GROUP BY 1,2,3,4,5,6,7
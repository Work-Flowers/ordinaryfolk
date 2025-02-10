WITH monthly_charges AS (
    SELECT
        ch.region,
        DATE(ch.created) AS created,
        ch.customer_id,
        MIN(MIN(DATE(ch.created))) OVER (PARTITION BY ch.customer_id) AS first_purchase,
        SUM(ch.amount / fx.fx_to_usd / 100) AS amount
    FROM all_stripe.charge ch
    LEFT JOIN ref.fx_rates fx
        ON ch.currency = fx.currency
    WHERE ch.status = 'succeeded'
    GROUP BY 1, 2, 3
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
    SELECT 
    	region,
    	customer_id,
    	MIN(DATE(created)) AS first_purchase
    FROM all_stripe.charge
    WHERE status = 'succeeded'
    GROUP BY 1,2
),

zero_filled_months AS (
    SELECT
        c.region,
        m.created,
        c.customer_id,
        c.first_purchase,
        0.0 AS amount
    FROM months m
    CROSS JOIN all_customers c
),

unioned AS (
	SELECT 
	    region,
	    created,
	    customer_id,
	    first_purchase,
	    amount
	FROM monthly_charges
	
	UNION ALL
	
	SELECT
	    region,
	    created,
	    customer_id,
	    first_purchase,
	    amount
	FROM zero_filled_months
)

SELECT
	region,
	DATE_TRUNC(created, MONTH) AS created,
	customer_id,
	DATE_TRUNC(first_purchase, MONTH) AS first_purchase,
	SUM(amount) AS amount
FROM unioned
WHERE DATE_TRUNC(created, MONTH) >= DATE_TRUNC(first_purchase, MONTH)
GROUP BY 1,2,3,4
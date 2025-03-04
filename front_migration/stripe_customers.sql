WITH subs_status AS(
	SELECT	
		id AS subscription_id,
		status,
		customer_id
	FROM all_stripe.subscription_history
	QUALIFY ROW_NUMBER() OVER(PARTITION BY id ORDER BY created DESC) = 1
),

subs_active AS (
	SELECT DISTINCT 
		customer_id
	FROM subs_status
	WHERE status = 'active'

)

SELECT
	cus.region,
	cus.id AS customer_id,
	cus.name,
	cus.email,
	cus.phone,
	ss.customer_id IS NOT NULL AS is_active_subscriber,
	MAX(ch.created) AS last_transaction_date
FROM all_stripe.customer AS cus
LEFT JOIN all_stripe.charge AS ch
	ON cus.id = ch.customer_id
	AND ch.status = 'succeeded'
LEFT JOIN subs_active AS ss
	ON cus.id = ss.customer_id
WHERE
	1 = 1
	AND (ss.customer_id IS NOT NULL OR ch.id IS NOT NULL)
GROUP BY 1,2,3,4,5,6
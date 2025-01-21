-- Drop the existing view if it exists
DROP VIEW IF EXISTS `all_stripe.customer_purchase_history`;

-- Create the view
CREATE VIEW `all_stripe.customer_purchase_history` AS

WITH
-- 1) Subscription Creation and Renewal Purchases
subscription_creation_renewals AS (
	SELECT DISTINCT
		inv.customer_id,
		DATE(inv.created) AS purchase_date,
		CASE 
			WHEN inv.billing_reason = 'subscription_create' THEN 'subscription_creation' 
			WHEN inv.billing_reason = 'subscription_cycle' THEN 'subscription_renewal'
			END AS purchase_type
	FROM `all_stripe.invoice` AS inv
	WHERE 
		inv.billing_reason IN ('subscription_create', 'subscription_cycle') -- Creation and reewnals only
),

-- 2) One-Time Purchases
one_time_purchases AS (
	SELECT DISTINCT
		ch.customer_id,
		DATE(ch.created) AS purchase_date,
		'one_time_purchase' AS purchase_type
	FROM `all_stripe.charge` AS ch
	WHERE 
		ch.invoice_id IS NULL -- Charges not tied to subscriptions or recurring invoices
		AND ch.status = 'succeeded' -- Ensure successful payments
)
-- 3) Combine All Purchases
SELECT
	customer_id,
	ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY  purchase_date) AS purchase_number,
	purchase_date AS purchase_date,
	LEAD(purchase_date) OVER (PARTITION BY customer_id ORDER BY purchase_date) AS next_purchase_date
FROM (
	SELECT *
	FROM subscription_creation_renewals
	UNION ALL
	SELECT *
	FROM one_time_purchases
)

ORDER BY customer_id, purchase_date;
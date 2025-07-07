DROP VIEW IF EXISTS finance_metrics.new_subs;
CREATE VIEW finance_metrics.new_subs AS 

WITH first_sub AS (
    SELECT
        customer_id,
        region,
        MIN(DATE(created)) AS first_sub_created
    FROM all_stripe.subscription_history
    WHERE status = 'active'
    GROUP BY 1,2
),

first_charge AS (
    SELECT 
        customer_id,
        region,
        MIN(DATE(created)) AS first_charge_created
    FROM all_stripe.charge
    WHERE status = 'succeeded'
    GROUP BY 1,2
)

SELECT
    fs.customer_id,
    fs.region,
    fs.first_sub_created
FROM first_sub AS fs
LEFT JOIN first_charge AS fc
    ON fs.customer_id = fc.customer_id
    AND fs.region = fc.region
       -- Only join if the charge was >7 days before subscription
    AND fc.first_charge_created <= DATE_SUB(fs.first_sub_created, INTERVAL 7 DAY)
WHERE 
    fc.first_charge_created IS NULL -- Only keep those with NO charge >7 days before sub
WITH landing AS (
	SELECT 
		DATE(p.timestamp) AS date,
		p.region,
		COUNT(DISTINCT p.user_id) AS n_users	
	FROM segment.pages AS p
	WHERE 
		category = 'Upgrade Introduction Page'
	GROUP BY 1,2
),

upgrades AS (
	SELECT
		DATE(t.timestamp) AS date,
		u.region,
		COUNT(DISTINCT t.user_id) AS n_users
	FROM segment.upgraded_plans AS u
	INNER JOIN segment.tracks AS t
		ON u.message_id = t.message_id
	GROUP BY 1,2
	ORDER BY 1 DESC
),

new_customers AS (
	SELECT DISTINCT
		DATE(created) AS date,
		region,
		COUNT(DISTINCT customer_id) AS n_new_customers
	FROM all_stripe.subscription_history	
	WHERE status = 'active'
	GROUP BY 1,2
),

all_keys AS (

	SELECT DISTINCT
		date,
		region
	FROM landing
	
	UNION DISTINCT
	
	SELECT DISTINCT
		date,
		region
	FROM upgrades
	
	UNION DISTINCT
	
	SELECT DISTINCT
		date,
		region
	FROM new_customers
)



SELECT
	k.date,
	k.region,
	COALESCE(landing.n_users, 0) AS n_landing,
	COALESCE(upgrades.n_users, 0) AS n_upgrades,
	COALESCE(nc.n_new_customers, 0) AS n_new_customers
FROM all_keys AS k
LEFT JOIN landing
	ON k.date = landing.date
	AND k.region = landing.region
LEFT JOIN upgrades
	ON k.date = upgrades.date
	AND k.region = upgrades.region
LEFT JOIN new_customers AS nc
	ON k.date = nc.date
	AND k.region = nc.region
	
ORDER BY  2, 1 DESC
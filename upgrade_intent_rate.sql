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
)

SELECT
	landing.date,
	landing.region,
	landing.n_users AS n_landing,
	COALESCE(upgrades.n_users, 0) AS n_upgrades
FROM landing
LEFT JOIN upgrades
	ON landing.date = upgrades.date
	AND landing.region = upgrades.region
DROP VIEW IF EXISTS all_postgres.user_emails;
CREATE VIEW all_postgres.user_emails AS 

SELECT
	email,
	sys_id,
	utm_source
FROM all_postgres.user
QUALIFY ROW_NUMBER() OVER(PARTITION BY email ORDER BY updated_at DESC) = 1
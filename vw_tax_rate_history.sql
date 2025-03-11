DROP VIEW IF EXISTS ref.tax_rate_history;
CREATE VIEW ref.tax_rate_history AS 

SELECT
	region,
	effective_from AS from_date,
	COALESCE(LEAD(effective_from, 1) OVER (PARTITION BY region ORDER BY effective_from), '9999-12-31') AS to_date,
	rate
FROM google_sheets.tax_rates
ORDER BY 1,2
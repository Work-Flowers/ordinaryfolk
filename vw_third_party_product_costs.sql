
-- lazada
DROP VIEW IF EXISTS finance_metrics.lazada_product_costs;
CREATE VIEW finance_metrics.lazada_product_costs AS

SELECT
	lc.* EXCEPT(effective_date),
	effective_date AS from_date,
	COALESCE(LEAD(effective_date, 1) OVER (PARTITION BY seller_sku ORDER BY effective_date), '9999-12-31') AS to_date
FROM google_sheets.lazada_cogs AS lc;	


-- shopee
DROP VIEW IF EXISTS finance_metrics.shopee_product_costs;
CREATE VIEW finance_metrics.shopee_product_costs AS

SELECT
	sc.* EXCEPT(effective_date),
	effective_date AS from_date,
	COALESCE(LEAD(effective_date, 1) OVER (PARTITION BY sku_reference_no_ ORDER BY effective_date), '9999-12-31') AS to_date
FROM google_sheets.shopee_cogs AS sc;	

-- tiktok

DROP VIEW IF EXISTS finance_metrics.tiktok_product_costs;
CREATE VIEW finance_metrics.tiktok_product_costs AS

SELECT
	tc.* EXCEPT(effective_date),
	effective_date AS from_date,
	COALESCE(LEAD(effective_date, 1) OVER (PARTITION BY sku_id ORDER BY effective_date), '9999-12-31') AS to_date
FROM google_sheets.tiktok_cogs AS tc;	
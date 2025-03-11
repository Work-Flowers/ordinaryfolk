DROP VIEW IF EXISTS all_postgres.user;
CREATE VIEW all_postgres.user AS 

SELECT 
    'sg' AS region,
    sg.* 
  FROM sg_postgres_rds_public.user AS sg

  UNION ALL

  SELECT 
    'hk' AS region,
    hk.* 
  FROM hk_postgres_rds_public.user AS hk

  UNION ALL

  SELECT 
    'jp' AS region,
    jp.* 
  FROM jp_postgres_rds_public.user AS jp;
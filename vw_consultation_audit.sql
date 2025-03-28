CREATE VIEW `noah-e30be.all_postgres.consultation_audit`
AS SELECT 
    'sg' AS region,
    sg.* 
  FROM sg_postgres_rds_public.consultation_audit AS sg

  UNION ALL

  SELECT 
    'hk' AS region,
    hk.* 
  FROM hk_postgres_rds_public.consultation_audit AS hk

  UNION ALL

  SELECT 
    'jp' AS region,
    jp.* 
  FROM jp_postgres_rds_public.consultation_audit AS jp;
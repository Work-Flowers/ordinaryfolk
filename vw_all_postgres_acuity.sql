DROP VIEW IF EXISTS all_postgres.acuity_appointment;
CREATE VIEW all_postgres.acuity_appointment AS 

SELECT 
    'sg' AS region,
    sg.* 
  FROM sg_postgres_rds_public.acuity_appointment AS sg

  UNION ALL

  SELECT 
    'hk' AS region,
    hk.* 
  FROM hk_postgres_rds_public.acuity_appointment AS hk

  UNION ALL

  SELECT 
    'jp' AS region,
    jp.* 
  FROM jp_postgres_rds_public.acuity_appointment AS jp;

DROP VIEW IF EXISTS all_postgres.order_acuity_appointment;
CREATE VIEW all_postgres.order_acuity_appointment AS 

SELECT 
    'sg' AS region,
    sg.* 
  FROM sg_postgres_rds_public.order_acuity_appointment AS sg

  UNION ALL

  SELECT 
    'hk' AS region,
    hk.* 
  FROM hk_postgres_rds_public.order_acuity_appointment AS hk

  UNION ALL

  SELECT 
    'jp' AS region,
    jp.* 
  FROM jp_postgres_rds_public.order_acuity_appointment AS jp;
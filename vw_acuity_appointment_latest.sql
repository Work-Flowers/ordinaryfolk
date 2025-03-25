DROP VIEW IF EXISTS all_postgres.acuity_appointment_latest;
CREATE VIEW all_postgres.acuity_appointment_latest AS

SELECT *
FROM all_postgres.acuity_appointment
QUALIFY ROW_NUMBER() OVER(PARTITION BY id ORDER BY updated_at DESC) = 1

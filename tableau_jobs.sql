SELECT 
	t.id AS refresh_task_id,
	t.datasource_id,
	t.workbook_id,
	t.schedule_next_run_at,
	CASE 
		WHEN t.datasource_id IS NOT NULL THEN 'Data Source'
		WHEN t.workbook_id  IS NOT NULL THEN 'Workbook'
		END AS type,
	COALESCE(ds.name, wb.name) AS name
FROM tableau_source.extract_refresh_task AS t
LEFT JOIN tableau_source.data_source AS ds
	ON t.datasource_id = ds.id
LEFT JOIN tableau_source.workbook AS wb
	ON t.workbook_id = wb.id
WHERE
	1 = 1
	AND t._fivetran_deleted IS FALSE
QUALIFY ROW_NUMBER() OVER (PARTITION BY COALESCE(t.datasource_id, t.workbook_id) ORDER BY t._fivetran_synced DESC) = 1

{{289692519__extractRefresh__workbook__id}}
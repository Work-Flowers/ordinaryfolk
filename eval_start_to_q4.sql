WITH eval_start AS (
  SELECT
    message_id,
    user_id,
    timestamp
  FROM segment.tracks AS t
  WHERE
    t.event = 'Evaluation Updated'
  QUALIFY ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY  timestamp ASC) = 1
),

viewed AS (
  SELECT
      user_id,
      timestamp
    FROM segment.tracks AS t
    WHERE
      t.event = 'Viewed 4th Question Of Eval'
    QUALIFY ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY  timestamp ASC) = 1
)

SELECT
  es.user_id,
  es.timestamp AS start_time,
  viewed.timestamp AS viewed_4_time,
  eu.platform,
  eu.region,
  eu.evaluation_type
FROM eval_start AS es
LEFT JOIN viewed
  ON es.user_id = viewed.user_id
LEFT JOIN `segment.evaluation_updated` AS eu
  ON es.message_id = eu.message_id
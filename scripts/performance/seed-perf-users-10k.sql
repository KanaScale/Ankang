-- Run once on the cloud TEST database after registering perf_user_001..100.
-- This creates 100 health records for each of 100 users: 10,000 rows total.
SET @records_per_user = 100;
SET SESSION cte_max_recursion_depth = 1001;

SELECT COUNT(*) AS perf_user_count
FROM `user`
WHERE username REGEXP '^perf_user_[0-9]{3}$';

INSERT INTO health_record (
  user_id,
  type,
  value,
  value1,
  unit,
  status,
  source,
  remark,
  recorded_at
)
WITH RECURSIVE sequence_per_user AS (
  SELECT 1 AS seq_num
  UNION ALL
  SELECT seq_num + 1
  FROM sequence_per_user
  WHERE seq_num < @records_per_user
)
SELECT
  perf_user.id,
  'heart_rate',
  60 + MOD(sequence_per_user.seq_num, 40),
  60 + MOD(sequence_per_user.seq_num, 40),
  'bpm',
  'normal',
  'manual',
  CONCAT('perf-batch-', sequence_per_user.seq_num),
  NOW()
    - INTERVAL MOD(sequence_per_user.seq_num, 100) DAY
    - INTERVAL MOD(perf_user.id, 3600) SECOND
FROM `user` AS perf_user
CROSS JOIN sequence_per_user
WHERE perf_user.username REGEXP '^perf_user_[0-9]{3}$'
  AND NOT EXISTS (
    SELECT 1
    FROM health_record AS existing_record
    WHERE existing_record.user_id = perf_user.id
      AND existing_record.remark =
          CONCAT('perf-batch-', sequence_per_user.seq_num)
  );

SELECT
  COUNT(DISTINCT perf_user.id) AS user_count,
  COUNT(health_record.id) AS record_count,
  MIN(per_user.record_count) AS min_records_per_user,
  MAX(per_user.record_count) AS max_records_per_user
FROM `user` AS perf_user
JOIN health_record
  ON health_record.user_id = perf_user.id
 AND health_record.remark LIKE 'perf-batch-%'
JOIN (
  SELECT user_id, COUNT(*) AS record_count
  FROM health_record
  WHERE remark LIKE 'perf-batch-%'
  GROUP BY user_id
) AS per_user
  ON per_user.user_id = perf_user.id
WHERE perf_user.username REGEXP '^perf_user_[0-9]{3}$';

-- Cleanup after the performance test:
-- DELETE health_record
-- FROM health_record
-- JOIN `user` ON `user`.id = health_record.user_id
-- WHERE `user`.username REGEXP '^perf_user_[0-9]{3}$'
--   AND health_record.remark LIKE 'perf-batch-%';

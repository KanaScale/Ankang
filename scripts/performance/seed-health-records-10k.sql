-- 仅在云端测试数据库执行，不要在生产数据库直接执行。
-- 将 perf_pressure_user 替换为专用压测账号。
SET @perf_username = 'perf_pressure_user';
SET @perf_user_id = (
  SELECT id
  FROM `user`
  WHERE username = @perf_username
  LIMIT 1
);

SELECT @perf_user_id AS perf_user_id;

SET SESSION cte_max_recursion_depth = 10001;

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
WITH RECURSIVE sequence_10k AS (
  SELECT 1 AS row_number
  UNION ALL
  SELECT row_number + 1
  FROM sequence_10k
  WHERE row_number < 10000
)
SELECT
  @perf_user_id,
  'heart_rate',
  60 + MOD(row_number, 40),
  60 + MOD(row_number, 40),
  'bpm',
  'normal',
  'manual',
  CONCAT('perf-test-', row_number),
  NOW()
    - INTERVAL MOD(row_number, 365) DAY
    - INTERVAL MOD(row_number, 86400) SECOND
FROM sequence_10k
WHERE @perf_user_id IS NOT NULL;

SELECT COUNT(*) AS perf_record_count
FROM health_record
WHERE user_id = @perf_user_id
  AND remark LIKE 'perf-test-%';

-- 测试完成后的清理命令：
-- DELETE FROM health_record
-- WHERE user_id = @perf_user_id
--   AND remark LIKE 'perf-test-%';

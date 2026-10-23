-- 重新计算历史健康记录状态，使其与录入页展示的参考范围保持一致。
UPDATE health_record
SET status = CASE
  WHEN type = 'blood_pressure'
       AND (systolic >= 160 OR diastolic >= 100)
    THEN 'danger'
  WHEN type = 'blood_pressure'
       AND (systolic >= 140 OR diastolic >= 90 OR systolic < 90 OR diastolic < 60)
    THEN 'warning'
  WHEN type = 'blood_pressure'
    THEN 'normal'

  WHEN type = 'blood_glucose'
       AND COALESCE(value, value1) >= 11.1
    THEN 'danger'
  WHEN type = 'blood_glucose'
       AND (COALESCE(value, value1) < 3.9 OR COALESCE(value, value1) > 6.1)
    THEN 'warning'
  WHEN type = 'blood_glucose'
    THEN 'normal'

  WHEN type = 'heart_rate'
       AND (COALESCE(value, value1) < 50 OR COALESCE(value, value1) > 120)
    THEN 'danger'
  WHEN type = 'heart_rate'
    AND (COALESCE(value, value1) < 60 OR COALESCE(value, value1) > 100)
    THEN 'warning'
  WHEN type = 'heart_rate'
    THEN 'normal'

  ELSE status
END
WHERE type IN ('blood_pressure', 'blood_glucose', 'heart_rate');

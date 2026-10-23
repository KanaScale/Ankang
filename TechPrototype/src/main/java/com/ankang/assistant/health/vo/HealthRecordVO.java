package com.ankang.assistant.health.vo;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public record HealthRecordVO(
        Long id,
        String type,
        BigDecimal value,
        BigDecimal value1,
        BigDecimal value2,
        Integer systolic,
        Integer diastolic,
        String unit,
        String status,
        String source,
        String remark,
        LocalDateTime recordedAt
) {
}

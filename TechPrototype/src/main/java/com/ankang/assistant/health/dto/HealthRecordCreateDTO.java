package com.ankang.assistant.health.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public record HealthRecordCreateDTO(
        @NotBlank String type,
        BigDecimal value,
        BigDecimal value1,
        BigDecimal value2,
        Integer systolic,
        Integer diastolic,
        @Size(max = 32) String unit,
        LocalDateTime recordedAt,
        @Size(max = 32) String source,
        @Size(max = 255) String remark,
        @Size(max = 255) String note
) {
}

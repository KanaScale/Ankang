package com.ankang.assistant.device.dto;

import java.math.BigDecimal;

public record DeviceCustomSyncDTO(
        BigDecimal heartRate,
        Integer systolic,
        Integer diastolic,
        BigDecimal bloodGlucose,
        BigDecimal steps,
        BigDecimal sleepHours
) {
}

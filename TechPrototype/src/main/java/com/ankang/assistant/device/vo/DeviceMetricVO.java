package com.ankang.assistant.device.vo;

import java.math.BigDecimal;

public record DeviceMetricVO(
        String type,
        String label,
        BigDecimal value,
        Integer systolic,
        Integer diastolic,
        String unit,
        String status
) {
}

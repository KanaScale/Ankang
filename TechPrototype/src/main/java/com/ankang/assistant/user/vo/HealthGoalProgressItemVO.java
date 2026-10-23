package com.ankang.assistant.user.vo;

import java.math.BigDecimal;

public record HealthGoalProgressItemVO(
        String key,
        String label,
        String targetText,
        String currentText,
        String unit,
        BigDecimal progress,
        String status
) {
}

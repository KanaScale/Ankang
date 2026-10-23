package com.ankang.assistant.family.vo;

import com.ankang.assistant.health.vo.HealthSummaryVO;

import java.time.LocalDateTime;

public record FamilyHealthSummaryVO(
        Long patientUserId,
        String patientName,
        LocalDateTime lastUpdateTime,
        HealthSummaryVO summary
) {
}

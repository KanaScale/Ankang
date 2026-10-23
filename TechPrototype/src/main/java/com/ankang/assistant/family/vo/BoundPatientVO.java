package com.ankang.assistant.family.vo;

import java.time.LocalDateTime;
import java.util.List;

public record BoundPatientVO(
        Long patientUserId,
        String patientName,
        String relationType,
        String status,
        String riskLevel,
        LocalDateTime lastUpdateTime,
        List<String> permissions
) {
}

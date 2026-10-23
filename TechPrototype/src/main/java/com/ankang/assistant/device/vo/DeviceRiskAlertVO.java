package com.ankang.assistant.device.vo;

import java.time.LocalDateTime;
import java.util.List;

public record DeviceRiskAlertVO(
        String eventId,
        String eventType,
        Long healthRecordId,
        String status,
        String riskLevel,
        Integer riskScore,
        String summary,
        List<String> reasons,
        Long sosEventId,
        LocalDateTime occurredAt,
        LocalDateTime processedAt,
        List<Object> timeline
) {
}

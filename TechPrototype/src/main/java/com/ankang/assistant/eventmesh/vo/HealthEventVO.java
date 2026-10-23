package com.ankang.assistant.eventmesh.vo;

import java.time.LocalDateTime;
import java.util.List;

public record HealthEventVO(
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
        List<HealthEventTimelineVO> timeline
) {
}

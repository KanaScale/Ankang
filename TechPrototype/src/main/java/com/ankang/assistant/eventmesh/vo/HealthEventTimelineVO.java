package com.ankang.assistant.eventmesh.vo;

import java.time.LocalDateTime;

public record HealthEventTimelineVO(String stage, String message, LocalDateTime occurredAt) {
}

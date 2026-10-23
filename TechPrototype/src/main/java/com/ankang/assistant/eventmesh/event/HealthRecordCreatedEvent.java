package com.ankang.assistant.eventmesh.event;

import java.time.LocalDateTime;

/** 健康记录成功提交后发布的领域事件。 */
public record HealthRecordCreatedEvent(Long userId, Long healthRecordId, LocalDateTime occurredAt) {
}

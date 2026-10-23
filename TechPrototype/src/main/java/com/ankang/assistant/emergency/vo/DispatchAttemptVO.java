package com.ankang.assistant.emergency.vo;

import java.time.LocalDateTime;

public record DispatchAttemptVO(
        String attemptId,
        Long contactId,
        String channel,
        String status,
        String errorCode,
        LocalDateTime occurredAt
) {
}

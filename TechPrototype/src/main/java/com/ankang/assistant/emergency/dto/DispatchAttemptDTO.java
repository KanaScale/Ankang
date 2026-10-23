package com.ankang.assistant.emergency.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.time.LocalDateTime;

public record DispatchAttemptDTO(
        @NotBlank @Size(max = 36) String attemptId,
        Long contactId,
        @NotBlank @Size(max = 16) String channel,
        @NotBlank @Size(max = 32) String status,
        @Size(max = 64) String errorCode,
        LocalDateTime occurredAt
) {
}

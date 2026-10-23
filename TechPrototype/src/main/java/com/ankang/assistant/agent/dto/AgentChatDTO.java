package com.ankang.assistant.agent.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record AgentChatDTO(
        Long sessionId,
        @NotBlank @Size(max = 1000) String message
) {
}

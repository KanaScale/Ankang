package com.ankang.assistant.agent.vo;

import java.time.LocalDateTime;

public record AgentMessageVO(
        Long id,
        String role,
        String content,
        LocalDateTime createdAt
) {
}

package com.ankang.assistant.agent.vo;

import java.time.LocalDateTime;

public record AgentSessionVO(
        Long id,
        String title,
        LocalDateTime updatedAt
) {
}

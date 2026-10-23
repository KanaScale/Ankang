package com.ankang.assistant.agent.action;

import java.util.Map;

public record AgentActionRequest(
        AgentActionType actionType,
        String title,
        String description,
        boolean requiresConfirmation,
        Map<String, Object> payload
) {
}

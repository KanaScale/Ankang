package com.ankang.assistant.agent.action;

import java.util.Map;

public record AgentActionResult(
        boolean success,
        String resultMessage,
        Map<String, Object> data
) {
    public static AgentActionResult success(String resultMessage, Map<String, Object> data) {
        return new AgentActionResult(true, resultMessage, data == null ? Map.of() : data);
    }

    public static AgentActionResult failure(String resultMessage) {
        return new AgentActionResult(false, resultMessage, Map.of());
    }
}

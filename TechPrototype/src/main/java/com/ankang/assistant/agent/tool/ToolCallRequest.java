package com.ankang.assistant.agent.tool;

import java.util.Map;

public record ToolCallRequest(
        String toolName,
        Map<String, String> arguments
) {
}

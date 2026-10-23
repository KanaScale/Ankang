package com.ankang.assistant.agent.tool;

import com.ankang.assistant.agent.action.AgentActionExecutionContext;
import com.ankang.assistant.agent.action.AgentActionResult;
import com.ankang.assistant.agent.action.AgentActionType;

import java.util.Map;

public interface AgentTool {
    String name();

    String description();

    ToolCallResult execute(Map<String, String> arguments);

    default boolean supportsAction(AgentActionType actionType) {
        return false;
    }

    default AgentActionResult executeAction(
            AgentActionExecutionContext context,
            Map<String, Object> payload
    ) {
        return AgentActionResult.failure("当前工具不支持该 Agent Action");
    }
}

package com.ankang.assistant.agent.tool;

import com.ankang.assistant.agent.action.AgentActionExecutionContext;
import com.ankang.assistant.agent.action.AgentActionResult;
import com.ankang.assistant.agent.action.AgentActionType;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
public class AgentToolExecutor {

    private final Map<String, AgentTool> tools;

    public AgentToolExecutor(List<AgentTool> tools) {
        this.tools = tools.stream().collect(Collectors.toMap(AgentTool::name, Function.identity()));
    }

    public Optional<ToolCallResult> execute(ToolCallRequest request) {
        if (request == null || request.toolName() == null) {
            return Optional.empty();
        }
        AgentTool tool = tools.get(request.toolName());
        if (tool == null) {
            return Optional.empty();
        }
        return Optional.of(tool.execute(request.arguments()));
    }

    public List<WebSearchResult> webSearch(String query) {
        return execute(new ToolCallRequest(WebSearchTool.TOOL_NAME, Map.of("query", query)))
                .filter(ToolCallResult::success)
                .map(ToolCallResult::webSearchResults)
                .orElse(List.of());
    }

    public AgentActionResult executeAction(
            AgentActionType actionType,
            AgentActionExecutionContext context,
            Map<String, Object> payload
    ) {
        if (actionType == null) {
            return AgentActionResult.failure("Agent Action 类型不能为空");
        }
        return tools.values().stream()
                .filter(tool -> tool.supportsAction(actionType))
                .findFirst()
                .map(tool -> tool.executeAction(context, payload))
                .orElseGet(() -> AgentActionResult.failure("暂不支持该 Agent Action: " + actionType));
    }
}

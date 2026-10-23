package com.ankang.assistant.agent.tool;

import com.ankang.assistant.agent.config.AgentProperties;
import org.springframework.stereotype.Component;

import java.util.Map;

@Component
public class WebSearchTool implements AgentTool {

    public static final String TOOL_NAME = "web_search";

    private final WebSearchClient webSearchClient;
    private final AgentProperties properties;

    public WebSearchTool(WebSearchClient webSearchClient, AgentProperties properties) {
        this.webSearchClient = webSearchClient;
        this.properties = properties;
    }

    @Override
    public String name() {
        return TOOL_NAME;
    }

    @Override
    public String description() {
        return "Searches public web health information and returns short source summaries.";
    }

    @Override
    public ToolCallResult execute(Map<String, String> arguments) {
        if (!properties.getWebSearch().isEnabled()) {
            return ToolCallResult.success(name(), java.util.List.of());
        }
        String query = arguments == null ? null : arguments.get("query");
        if (query == null || query.isBlank()) {
            return ToolCallResult.success(name(), java.util.List.of());
        }
        try {
            return ToolCallResult.success(
                    name(),
                    webSearchClient.search(query, properties.getWebSearch().getMaxResults())
            );
        } catch (RuntimeException ex) {
            return ToolCallResult.failure(name(), ex.getMessage());
        }
    }
}

package com.ankang.assistant.agent.tool;

import java.util.List;

public record ToolCallResult(
        String toolName,
        boolean success,
        List<WebSearchResult> webSearchResults,
        String errorMessage
) {
    public static ToolCallResult success(String toolName, List<WebSearchResult> results) {
        return new ToolCallResult(toolName, true, results == null ? List.of() : results, null);
    }

    public static ToolCallResult failure(String toolName, String errorMessage) {
        return new ToolCallResult(toolName, false, List.of(), errorMessage);
    }
}

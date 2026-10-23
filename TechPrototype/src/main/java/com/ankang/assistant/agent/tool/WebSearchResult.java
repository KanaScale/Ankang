package com.ankang.assistant.agent.tool;

public record WebSearchResult(
        String title,
        String url,
        String snippet,
        String source
) {
}

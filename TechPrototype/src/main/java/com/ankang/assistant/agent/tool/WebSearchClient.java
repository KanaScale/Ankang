package com.ankang.assistant.agent.tool;

import java.util.List;

public interface WebSearchClient {
    List<WebSearchResult> search(String query, int maxResults);
}

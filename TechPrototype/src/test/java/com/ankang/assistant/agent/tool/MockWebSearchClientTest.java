package com.ankang.assistant.agent.tool;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class MockWebSearchClientTest {

    @Test
    void mockSearchReturnsResults() {
        List<WebSearchResult> results = new MockWebSearchClient().search("最新高血压指南", 5);

        assertThat(results).isNotEmpty();
        assertThat(results.get(0).source()).isEqualTo("web_search");
    }

    @Test
    void mockSearchDoesNotRequireApiKey() {
        List<WebSearchResult> results = new MockWebSearchClient().search("药品副作用", 2);

        assertThat(results).hasSizeLessThanOrEqualTo(2);
        assertThat(results).allSatisfy(result -> assertThat(result.title()).isNotBlank());
    }

    @Test
    void invalidQueriesAndLimitsReturnNoResults() {
        MockWebSearchClient client = new MockWebSearchClient();
        assertThat(client.search(null, 2)).isEmpty();
        assertThat(client.search("", 2)).isEmpty();
        assertThat(client.search("   ", 2)).isEmpty();
        assertThat(client.search("健康", 0)).isEmpty();
        assertThat(client.search("健康", -1)).isEmpty();
    }

    @Test
    void everyKeywordAlternativeAndGeneralFallbackAreCovered() {
        MockWebSearchClient client = new MockWebSearchClient();

        assertThat(client.search("血压管理", 1)).hasSize(1);
        assertThat(client.search("药物", 5)).hasSize(2);
        assertThat(client.search("常见副作用", 5)).hasSize(2);
        assertThat(client.search("用药禁忌", 5)).hasSize(2);
        assertThat(client.search("睡眠与运动", 5)).hasSize(2);
    }
}

package com.ankang.assistant.agent;

import com.ankang.assistant.agent.action.AgentIntentParser;
import com.ankang.assistant.agent.config.AgentProperties;
import com.ankang.assistant.agent.mapper.AgentMemoryMapper;
import com.ankang.assistant.agent.service.AgentMemoryService;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

class AgentBranchCoverageTest {

    @Test
    void propertiesCoverFallbacksAndEveryProviderGate() {
        AgentProperties properties = new AgentProperties();

        properties.setGms(null);
        assertThat(properties.getGms()).isNotNull();
        ReflectionTestUtils.setField(properties, "gms", null);
        assertThat(properties.getGms()).isNotNull();

        properties.setProvider("mock");
        properties.setApiKey("key");
        assertThat(properties.llmEnabled()).isFalse();
        properties.setProvider("openai");
        properties.setApiKey(null);
        assertThat(properties.llmEnabled()).isFalse();
        properties.setApiKey(" ");
        assertThat(properties.llmEnabled()).isFalse();
        properties.setApiKey("key");
        assertThat(properties.llmEnabled()).isTrue();

        AgentProperties.WebSearch search = properties.getWebSearch();
        for (Integer value : new Integer[]{null, 0, -1}) {
            search.setMaxResults(value);
            search.setTimeoutSeconds(value);
            assertThat(search.getMaxResults()).isEqualTo(5);
            assertThat(search.getTimeoutSeconds()).isEqualTo(8);
        }
        search.setMaxResults(9);
        search.setTimeoutSeconds(11);
        assertThat(search.getMaxResults()).isEqualTo(9);
        assertThat(search.getTimeoutSeconds()).isEqualTo(11);

        search.setEnabled(false);
        assertThat(search.realProviderEnabled()).isFalse();
        search.setEnabled(true);
        search.setProvider(null);
        assertThat(search.realProviderEnabled()).isFalse();
        search.setProvider("mock");
        assertThat(search.realProviderEnabled()).isFalse();
        search.setProvider("bing");
        search.setApiKey(null);
        assertThat(search.realProviderEnabled()).isFalse();
        search.setApiKey(" ");
        assertThat(search.realProviderEnabled()).isFalse();
        search.setApiKey("key");
        assertThat(search.realProviderEnabled()).isTrue();

        AgentProperties.Gms gms = properties.getGms();
        for (String value : new String[]{null, "", " "}) {
            gms.setBaseUrl(value);
            assertThat(gms.getBaseUrl()).isEqualTo("http://127.0.0.1:8091");
        }
        gms.setBaseUrl("http://gms.test");
        assertThat(gms.getBaseUrl()).isEqualTo("http://gms.test");
        for (Integer value : new Integer[]{null, 0, -1}) {
            gms.setTimeoutMillis(value);
            gms.setReadLimit(value);
            assertThat(gms.getTimeoutMillis()).isEqualTo(800);
            assertThat(gms.getReadLimit()).isEqualTo(5);
        }
        gms.setTimeoutMillis(123);
        gms.setReadLimit(7);
        assertThat(gms.getTimeoutMillis()).isEqualTo(123);
        assertThat(gms.getReadLimit()).isEqualTo(7);
    }

    @Test
    void memoryClassifierCoversAlternativeKeywordsAndCompoundHealthNoteGate() {
        AgentMemoryService service = new AgentMemoryService(mock(AgentMemoryMapper.class));

        assertMemoryKeys(service, "chronic_disease", "糖尿病", "慢病", "冠心病");
        assertMemoryKeys(service, "medication", "长期服用", "每天吃药", "用药");
        assertMemoryKeys(service, "exercise_habit", "运动习惯", "每天走路", "跑步");
        assertMemoryKeys(service, "diet_limit", "忌口", "饮食限制", "不能吃辣", "少盐");
        assertMemoryKeys(service, "care_preference", "照护", "家人提醒", "医生建议");
        assertMemoryKeys(service, "health_note", "请记住健康信息", "记住医生的话", "记住药量", "记住病情");

        assertThat(memoryKey(service, "记住普通聊天")).isNull();
        assertThat(memoryKey(service, "只有健康两个字")).isNull();
    }

    @Test
    void intentParserPrivateHelpersCoverAbsentTopicsMultipleHintsAndRelativeDates() {
        AgentIntentParser parser = new AgentIntentParser();

        assertThat((String) ReflectionTestUtils.invokeMethod(
                parser, "topicWindow", "前缀目标后缀", new String[]{"不存在", "目标"}
        )).contains("目标");
        assertThat((String) ReflectionTestUtils.invokeMethod(
                parser, "topicWindow", "完全无关", new String[]{"目标"}
        )).isEmpty();
        assertThat((String) ReflectionTestUtils.invokeMethod(
                parser, "resolveNearestNumericTime", "早上8点散步", new String[]{"服药"}
        )).isNull();
        assertThat((String) ReflectionTestUtils.invokeMethod(
                parser, "resolveNearestTimeHint", "早上散步", new String[]{"服药"}
        )).isNull();

        assertThat((Integer) ReflectionTestUtils.invokeMethod(
                parser, "countTimeHints", "早上8点，中午12点，晚上9点"
        )).isGreaterThan(3);
        assertThat((String) ReflectionTestUtils.invokeMethod(
                parser, "resolveTimeText", "下午3点"
        )).isEqualTo("15:00");
        assertThat((String) ReflectionTestUtils.invokeMethod(
                parser, "resolveTimeText", "没有时间"
        )).isNull();
        assertThat((Boolean) ReflectionTestUtils.invokeMethod(
                parser, "hasRecordVerb", "普通问题"
        )).isFalse();
        assertThat((Boolean) ReflectionTestUtils.invokeMethod(
                parser, "hasMetricWithNumber", "普通问题"
        )).isFalse();

        assertThat(parser.parse("帮我每天上午测血压，晚上服药，没有具体时间"))
                .isPresent();
        assertThat(parser.parse("前天体重65公斤，帮我记录")).isPresent();
    }

    private void assertMemoryKeys(AgentMemoryService service, String expected, String... messages) {
        for (String message : messages) {
            assertThat(memoryKey(service, message)).isEqualTo(expected);
        }
    }

    private String memoryKey(AgentMemoryService service, String message) {
        return ReflectionTestUtils.invokeMethod(service, "extractMemoryKey", message);
    }
}

package com.ankang.assistant.agent.service;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class AgentToolDecisionServiceTest {

    private final AgentToolDecisionService service = new AgentToolDecisionService();

    @Test
    void latestGuidelineQuestionTriggersWebSearch() {
        assertThat(service.shouldUseWebSearch("最新高血压指南怎么说？")).isTrue();
    }

    @Test
    void ordinaryHealthRecordQuestionDoesNotTriggerWebSearch() {
        assertThat(service.shouldUseWebSearch("我今天血压 130/85 正常吗？")).isFalse();
    }
}

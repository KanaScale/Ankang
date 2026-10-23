package com.ankang.assistant.agent.service;

import com.ankang.assistant.agent.entity.AgentMemory;
import com.ankang.assistant.agent.gms.GmsMemoryItem;
import com.ankang.assistant.agent.llm.AgentChatTurn;
import com.ankang.assistant.agent.llm.MockAgentLlmClient;
import com.ankang.assistant.agent.tool.WebSearchResult;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class AgentSupportServiceCoverageTest {

    @Test
    void mockModelReturnsEveryTopicSpecificFallback() {
        MockAgentLlmClient client = new MockAgentLlmClient();
        assertThat(client.realModel()).isFalse();
        for (String message : List.of("血压怎么样", "血糖怎么样", "吃药提醒", "普通问题")) {
            assertThat(client.chat("system", List.of(
                    new AgentChatTurn("assistant", "old"),
                    new AgentChatTurn("user", message)
            ))).isNotBlank();
        }
        assertThat(client.chat("system", List.of())).isNotBlank();
    }

    @Test
    void promptBuilderIncludesCaregiverMemorySemanticAndWebSections() {
        AgentMemory memory = new AgentMemory();
        memory.setMemoryValue("long term memory");
        String prompt = new AgentPromptBuilder().build(
                "context",
                List.of(memory),
                List.of(new GmsMemoryItem("semantic", "fact", "app", 0.8)),
                List.of(new WebSearchResult("title", "https://example.test", "snippet", "web")),
                "safety",
                "CAREGIVER"
        );
        assertThat(prompt).contains(
                "context", "long term memory", "semantic",
                "title", "snippet", "https://example.test", "safety"
        );
        assertThat(new AgentPromptBuilder().build(
                "context", null, null, "safety"
        )).contains("context", "safety");
    }

    @Test
    void safetyServiceCoversNullMedicationEmergencyAndExistingNotice() {
        AgentSafetyService safety = new AgentSafetyService();
        assertThat(safety.hasEmergencyRisk(null)).isFalse();
        assertThat(safety.hasEmergencyRisk(" ")).isFalse();
        assertThat(safety.isMedicationRelated(null)).isFalse();
        assertThat(safety.isMedicationRelated("药物剂量")).isTrue();
        assertThat(safety.safetyInstruction("胸痛并咨询药物剂量"))
                .contains(AgentSafetyService.EMERGENCY_NOTICE);
        assertThat(safety.enforceEmergencyNotice("普通问题", "answer")).isEqualTo("answer");
        assertThat(safety.enforceEmergencyNotice("胸痛", null))
                .contains(AgentSafetyService.EMERGENCY_NOTICE);
        String alreadySafe = AgentSafetyService.EMERGENCY_NOTICE + "。";
        assertThat(safety.enforceEmergencyNotice("胸痛", alreadySafe)).isEqualTo(alreadySafe);
    }
}

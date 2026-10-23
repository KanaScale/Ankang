package com.ankang.assistant.agent.service;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class AgentSafetyServiceTest {

    private final AgentSafetyService service = new AgentSafetyService();

    @Test
    void emergencySymptomsTriggerEmergencyNotice() {
        assertThat(service.hasEmergencyRisk("老人突然胸痛并且呼吸困难")).isTrue();
        assertThat(service.enforceEmergencyNotice("老人突然胸痛", "请先休息观察"))
                .contains(AgentSafetyService.EMERGENCY_NOTICE);
    }

    @Test
    void ordinaryQuestionDoesNotInjectEmergencyNotice() {
        assertThat(service.hasEmergencyRisk("我今天血压 130/85 正常吗")).isFalse();
        assertThat(service.enforceEmergencyNotice("我今天血压 130/85 正常吗", "可以继续记录"))
                .isEqualTo("可以继续记录");
    }
}

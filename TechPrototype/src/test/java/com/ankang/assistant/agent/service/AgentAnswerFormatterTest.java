package com.ankang.assistant.agent.service;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class AgentAnswerFormatterTest {

    private final AgentAnswerFormatter formatter = new AgentAnswerFormatter();

    @Test
    void removesMarkdownMarkersForChatBubbleDisplay() {
        String result = formatter.format("""
                ## 建议
                **血压管理** 可以先观察。
                - 早晚固定时间测量
                `遵医嘱`
                """);

        assertThat(result).doesNotContain("**", "##", "`", "- ");
        assertThat(result).contains("血压管理 可以先观察。");
        assertThat(result).contains("早晚固定时间测量");
    }
}

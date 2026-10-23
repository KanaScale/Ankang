package com.ankang.assistant.agent.llm;

public record AgentChatTurn(
        String role,
        String content
) {
}

package com.ankang.assistant.agent.llm;

import java.util.List;

public interface AgentLlmClient {
    String chat(String systemPrompt, List<AgentChatTurn> turns);

    boolean realModel();
}

package com.ankang.assistant.agent.llm;

import dev.langchain4j.data.message.AiMessage;
import dev.langchain4j.data.message.ChatMessage;
import dev.langchain4j.data.message.SystemMessage;
import dev.langchain4j.data.message.UserMessage;
import dev.langchain4j.model.chat.ChatModel;

import java.util.ArrayList;
import java.util.List;

public class LangChain4jAgentLlmClient implements AgentLlmClient {

    private final ChatModel chatModel;

    public LangChain4jAgentLlmClient(ChatModel chatModel) {
        this.chatModel = chatModel;
    }

    @Override
    public String chat(String systemPrompt, List<AgentChatTurn> turns) {
        List<ChatMessage> messages = new ArrayList<>();
        messages.add(SystemMessage.from(systemPrompt));
        for (AgentChatTurn turn : turns) {
            if ("assistant".equals(turn.role())) {
                messages.add(AiMessage.from(turn.content()));
            } else {
                messages.add(UserMessage.from(turn.content()));
            }
        }
        return chatModel.chat(messages).aiMessage().text();
    }

    @Override
    public boolean realModel() {
        return true;
    }
}

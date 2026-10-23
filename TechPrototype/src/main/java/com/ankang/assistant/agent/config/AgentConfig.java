package com.ankang.assistant.agent.config;

import com.ankang.assistant.agent.llm.AgentLlmClient;
import com.ankang.assistant.agent.llm.LangChain4jAgentLlmClient;
import com.ankang.assistant.agent.llm.MockAgentLlmClient;
import dev.langchain4j.model.chat.ChatModel;
import dev.langchain4j.model.openai.OpenAiChatModel;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
@EnableConfigurationProperties(AgentProperties.class)
public class AgentConfig {

    @Bean
    public AgentLlmClient agentLlmClient(AgentProperties properties) {
        if (!properties.llmEnabled()) {
            return new MockAgentLlmClient();
        }
        ChatModel chatModel = OpenAiChatModel.builder()
                .baseUrl(properties.getBaseUrl())
                .apiKey(properties.getApiKey())
                .modelName(properties.getModelName())
                .build();
        return new LangChain4jAgentLlmClient(chatModel);
    }
}

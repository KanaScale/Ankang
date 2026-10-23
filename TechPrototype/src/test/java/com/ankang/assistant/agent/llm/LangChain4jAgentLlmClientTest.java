package com.ankang.assistant.agent.llm;

import dev.langchain4j.data.message.AiMessage;
import dev.langchain4j.data.message.ChatMessage;
import dev.langchain4j.data.message.SystemMessage;
import dev.langchain4j.data.message.UserMessage;
import dev.langchain4j.model.chat.ChatModel;
import dev.langchain4j.model.chat.response.ChatResponse;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class LangChain4jAgentLlmClientTest {

    @Test
    void convertsEveryTurnRoleAndReturnsModelText() {
        ChatModel model = mock(ChatModel.class);
        when(model.chat(anyList())).thenReturn(
                ChatResponse.builder().aiMessage(AiMessage.from("模型回答")).build()
        );
        LangChain4jAgentLlmClient client = new LangChain4jAgentLlmClient(model);

        String answer = client.chat("系统规则", List.of(
                new AgentChatTurn("user", "用户问题"),
                new AgentChatTurn("assistant", "历史回答"),
                new AgentChatTurn("tool", "非 assistant 角色按用户消息传递")
        ));

        assertThat(answer).isEqualTo("模型回答");
        assertThat(client.realModel()).isTrue();
        @SuppressWarnings("unchecked")
        ArgumentCaptor<List<ChatMessage>> captor = ArgumentCaptor.forClass(List.class);
        verify(model).chat(captor.capture());
        assertThat(captor.getValue())
                .hasSize(4)
                .element(0).isInstanceOf(SystemMessage.class);
        assertThat(captor.getValue().get(1)).isInstanceOf(UserMessage.class);
        assertThat(captor.getValue().get(2)).isInstanceOf(AiMessage.class);
        assertThat(captor.getValue().get(3)).isInstanceOf(UserMessage.class);
    }

    @Test
    void acceptsAnEmptyConversation() {
        ChatModel model = mock(ChatModel.class);
        when(model.chat(anyList())).thenReturn(
                ChatResponse.builder().aiMessage(AiMessage.from("ok")).build()
        );
        LangChain4jAgentLlmClient client = new LangChain4jAgentLlmClient(model);

        assertThat(client.chat("system", List.of())).isEqualTo("ok");
    }
}

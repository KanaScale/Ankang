package com.ankang.assistant.agent.service;

import com.ankang.assistant.agent.dto.AgentChatDTO;
import com.ankang.assistant.agent.vo.AgentReplyVO;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.timeout;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class AgentStreamServiceTest {

    @Test
    void streamsSuccessfulReplyAndCompletesAsyncTask() {
        AgentService agentService = mock(AgentService.class);
        AgentChatDTO dto = new AgentChatDTO(null, "hello");
        when(agentService.chat(dto)).thenReturn(new AgentReplyVO(
                1L, 2L, "a response longer than eight chars",
                List.of(), List.of("next"), null
        ));

        SseEmitter emitter = new AgentStreamService(agentService).chatStream(dto);

        assertThat(emitter.getTimeout()).isEqualTo(60_000L);
        verify(agentService, timeout(2000)).chat(dto);
    }

    @Test
    void asynchronousFailureIsCaughtAndNullAnswerProducesNoChunks() throws Exception {
        AgentService agentService = mock(AgentService.class);
        AgentChatDTO dto = new AgentChatDTO(null, "fail");
        when(agentService.chat(dto)).thenThrow(new IllegalStateException("failed"));
        new AgentStreamService(agentService).chatStream(dto);
        verify(agentService, timeout(2000)).chat(dto);

        AgentStreamService service = new AgentStreamService(agentService);
        SseEmitter emitter = mock(SseEmitter.class);
        ReflectionTestUtils.invokeMethod(service, "sendAnswerChunks", emitter, null);
        ReflectionTestUtils.invokeMethod(service, "sendAnswerChunks", emitter, "123456789");
        verify(emitter, org.mockito.Mockito.times(2)).send(any(SseEmitter.SseEventBuilder.class));
    }
}

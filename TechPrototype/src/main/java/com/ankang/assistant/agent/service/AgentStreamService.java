package com.ankang.assistant.agent.service;

import com.ankang.assistant.agent.dto.AgentChatDTO;
import com.ankang.assistant.agent.vo.AgentReplyVO;
import com.ankang.assistant.agent.vo.AgentStreamDoneVO;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.util.concurrent.CompletableFuture;

@Service
public class AgentStreamService {

    private static final long TIMEOUT_MILLIS = 60_000L;
    private static final int CHUNK_SIZE = 8;

    private final AgentService agentService;

    public AgentStreamService(AgentService agentService) {
        this.agentService = agentService;
    }

    public SseEmitter chatStream(AgentChatDTO dto) {
        SseEmitter emitter = new SseEmitter(TIMEOUT_MILLIS);
        SecurityContext securityContext = SecurityContextHolder.getContext();
        CompletableFuture.runAsync(() -> {
            SecurityContextHolder.setContext(securityContext);
            try {
                AgentReplyVO reply = agentService.chat(dto);
                sendAnswerChunks(emitter, reply.answer());
                emitter.send(SseEmitter.event()
                        .name("done")
                        .data(new AgentStreamDoneVO(
                                reply.sessionId(),
                                reply.messageId(),
                                reply.citations(),
                                reply.suggestions(),
                                reply.pendingAction()
                        )));
                emitter.complete();
            } catch (Exception ex) {
                emitter.completeWithError(ex);
            } finally {
                SecurityContextHolder.clearContext();
            }
        });
        return emitter;
    }

    private void sendAnswerChunks(SseEmitter emitter, String answer) throws IOException {
        String text = answer == null ? "" : answer;
        for (int start = 0; start < text.length(); start += CHUNK_SIZE) {
            int end = Math.min(start + CHUNK_SIZE, text.length());
            emitter.send(SseEmitter.event().name("token").data(text.substring(start, end)));
        }
    }
}

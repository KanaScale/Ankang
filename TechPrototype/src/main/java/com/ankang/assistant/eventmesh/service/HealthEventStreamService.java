package com.ankang.assistant.eventmesh.service;

import com.ankang.assistant.eventmesh.vo.HealthEventVO;
import org.springframework.stereotype.Service;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class HealthEventStreamService {

    private static final long TIMEOUT_MILLIS = 30L * 60L * 1000L;
    private final ConcurrentHashMap<Long, Set<SseEmitter>> emitters = new ConcurrentHashMap<>();

    public SseEmitter subscribe(Long userId) {
        SseEmitter emitter = new SseEmitter(TIMEOUT_MILLIS);
        emitters.computeIfAbsent(userId, ignored -> ConcurrentHashMap.newKeySet()).add(emitter);
        Runnable cleanup = () -> remove(userId, emitter);
        emitter.onCompletion(cleanup);
        emitter.onTimeout(cleanup);
        emitter.onError(ignored -> cleanup.run());
        try {
            emitter.send(SseEmitter.event().name("connected").data("health-event-stream-ready"));
        } catch (IOException ex) {
            cleanup.run();
            emitter.completeWithError(ex);
        }
        return emitter;
    }

    public void publish(Long userId, HealthEventVO event) {
        Set<SseEmitter> userEmitters = emitters.getOrDefault(userId, Set.of());
        for (SseEmitter emitter : userEmitters) {
            try {
                emitter.send(SseEmitter.event()
                        .id(event.eventId())
                        .name("health-risk-alert")
                        .data(event));
            } catch (IOException | IllegalStateException ex) {
                remove(userId, emitter);
                emitter.complete();
            }
        }
    }

    private void remove(Long userId, SseEmitter emitter) {
        Set<SseEmitter> userEmitters = emitters.get(userId);
        if (userEmitters != null) {
            userEmitters.remove(emitter);
            if (userEmitters.isEmpty()) {
                emitters.remove(userId, userEmitters);
            }
        }
    }
}

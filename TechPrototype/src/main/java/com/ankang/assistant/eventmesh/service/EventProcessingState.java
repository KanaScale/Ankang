package com.ankang.assistant.eventmesh.service;

import java.util.Set;

/** 事件处理状态机；禁止跳过关键处理阶段。 */
public enum EventProcessingState {
    RECEIVED(Set.of("published", "failed")),
    PUBLISHED(Set.of("assessing", "failed")),
    ASSESSING(Set.of("alerted", "failed")),
    ALERTED(Set.of("sos_prepared", "pushed", "failed")),
    SOS_PREPARED(Set.of("pushed", "failed")),
    PUSHED(Set.of("completed", "failed")),
    COMPLETED(Set.of()),
    FAILED(Set.of());

    private final Set<String> nextStates;

    EventProcessingState(Set<String> nextStates) {
        this.nextStates = nextStates;
    }

    public String value() {
        return name().toLowerCase();
    }

    public boolean canTransitionTo(EventProcessingState next) {
        return nextStates.contains(next.value());
    }
}

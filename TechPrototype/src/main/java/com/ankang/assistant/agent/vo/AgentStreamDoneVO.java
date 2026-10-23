package com.ankang.assistant.agent.vo;

import com.ankang.assistant.agent.action.AgentActionVO;

import java.util.List;

public record AgentStreamDoneVO(
        Long sessionId,
        Long messageId,
        List<AgentCitationVO> citations,
        List<String> suggestions,
        AgentActionVO pendingAction
) {
    public AgentStreamDoneVO(
            Long sessionId,
            Long messageId,
            List<AgentCitationVO> citations,
            List<String> suggestions
    ) {
        this(sessionId, messageId, citations, suggestions, null);
    }
}

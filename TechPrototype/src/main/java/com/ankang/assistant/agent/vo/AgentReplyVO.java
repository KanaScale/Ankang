package com.ankang.assistant.agent.vo;

import com.ankang.assistant.agent.action.AgentActionVO;

import java.util.List;

public record AgentReplyVO(
        Long sessionId,
        Long messageId,
        String answer,
        List<AgentCitationVO> citations,
        List<String> suggestions,
        AgentActionVO pendingAction
) {
    public AgentReplyVO(
            Long sessionId,
            Long messageId,
            String answer,
            List<AgentCitationVO> citations,
            List<String> suggestions
    ) {
        this(sessionId, messageId, answer, citations, suggestions, null);
    }
}

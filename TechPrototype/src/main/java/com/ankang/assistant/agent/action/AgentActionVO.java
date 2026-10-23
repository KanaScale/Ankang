package com.ankang.assistant.agent.action;

import java.util.Map;

public record AgentActionVO(
        String actionId,
        String actionType,
        String title,
        String description,
        Boolean requiresConfirmation,
        String status,
        Map<String, Object> payload,
        String resultMessage,
        Map<String, Object> result
) {
    public static AgentActionVO pending(
            String actionId,
            AgentActionType actionType,
            String title,
            String description,
            boolean requiresConfirmation,
            Map<String, Object> payload
    ) {
        return new AgentActionVO(
                actionId,
                actionType.name(),
                title,
                description,
                requiresConfirmation,
                AgentActionStatus.PENDING_CONFIRMATION.name(),
                payload,
                null,
                null
        );
    }

    public static AgentActionVO result(
            String actionId,
            AgentActionType actionType,
            AgentActionStatus status,
            Map<String, Object> payload,
            String resultMessage,
            Map<String, Object> result
    ) {
        return new AgentActionVO(
                actionId,
                actionType.name(),
                null,
                null,
                false,
                status.name(),
                payload,
                resultMessage,
                result
        );
    }
}

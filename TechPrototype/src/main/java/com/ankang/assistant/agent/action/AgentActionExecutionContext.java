package com.ankang.assistant.agent.action;

public record AgentActionExecutionContext(
        String actionId,
        Long actorUserId,
        Long targetUserId,
        Long sessionId,
        String actorRole
) {
    public boolean patientActor() {
        return actorRole == null || "PATIENT".equals(actorRole);
    }

    public boolean caregiverActor() {
        return "CAREGIVER".equals(actorRole);
    }
}

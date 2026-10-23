package com.ankang.assistant.agent.action;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record AgentActionConfirmRequest(
        @NotBlank String actionId,
        @NotNull Boolean confirmed
) {
}

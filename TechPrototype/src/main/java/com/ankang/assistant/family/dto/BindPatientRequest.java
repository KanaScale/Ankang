package com.ankang.assistant.family.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record BindPatientRequest(
        @NotBlank @Size(max = 64) String inviteCode,
        @Size(max = 32) String relationType
) {
}

package com.ankang.assistant.auth.dto;

import jakarta.validation.constraints.NotBlank;

public record PasswordResetCodeDTO(
        @NotBlank String username,
        @NotBlank String phone
) {
}

package com.ankang.assistant.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record PasswordResetDTO(
        @NotBlank String username,
        @NotBlank String phone,
        @NotBlank String code,
        @NotBlank @Size(min = 6) String newPassword,
        String confirmPassword
) {
}

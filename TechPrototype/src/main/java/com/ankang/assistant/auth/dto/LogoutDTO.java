package com.ankang.assistant.auth.dto;

import jakarta.validation.constraints.NotBlank;

public record LogoutDTO(
        @NotBlank String refreshToken
) {
}

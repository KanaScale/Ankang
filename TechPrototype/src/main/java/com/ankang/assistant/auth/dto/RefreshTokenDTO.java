package com.ankang.assistant.auth.dto;

import jakarta.validation.constraints.NotBlank;

public record RefreshTokenDTO(
        @NotBlank String refreshToken
) {
}

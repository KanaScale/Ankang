package com.ankang.assistant.auth.dto;

import jakarta.validation.constraints.NotBlank;

public record LoginDTO(
        @NotBlank String username,
        @NotBlank String password,
        Boolean keepSignedIn
) {
    public boolean shouldKeepSignedIn() {
        return Boolean.TRUE.equals(keepSignedIn);
    }
}

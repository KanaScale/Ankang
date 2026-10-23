package com.ankang.assistant.auth.vo;

public record PasswordResetCodeVO(
        String message,
        String devCode,
        long expiresInSeconds
) {
}

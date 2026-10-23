package com.ankang.assistant.user.dto;

public record PasswordChangeDTO(
        String oldPassword,
        String newPassword,
        String confirmPassword
) {
}

package com.ankang.assistant.user.vo;

public record UserProfileVO(
        Long id,
        String username,
        String nickname,
        Integer age,
        String gender,
        String phone,
        String email,
        String avatarUrl,
        String role
) {
}

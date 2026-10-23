package com.ankang.assistant.user.dto;

import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record UserProfileUpdateDTO(
        String username,
        @Size(max = 20, message = "用户名不能超过 20 个字符") String nickname,
        Integer age,
        @Pattern(regexp = "男|女|", message = "性别只能选择男或女") String gender,
        String phone,
        String email,
        String avatarUrl
) {
}

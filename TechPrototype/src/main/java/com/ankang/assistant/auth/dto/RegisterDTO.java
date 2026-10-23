package com.ankang.assistant.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record RegisterDTO(
        @NotBlank(message = "请输入账号")
        @Size(min = 4, max = 20, message = "账号长度需为 4-20 个字符") String username,
        @NotBlank @Size(min = 6) String password,
        String confirmPassword,
        String phone
) {
}

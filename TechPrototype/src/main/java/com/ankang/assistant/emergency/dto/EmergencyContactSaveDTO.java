package com.ankang.assistant.emergency.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record EmergencyContactSaveDTO(
        @Size(max = 36) String clientContactId,
        @NotBlank @Size(max = 64) String name,
        @Size(max = 64) String relation,
        @Size(max = 64) String relationship,
        @NotBlank
        @Pattern(regexp = "^1[3-9]\\d{9}$", message = "请输入正确的大陆手机号")
        String phone,
        @Min(value = 0, message = "priority 只能为 0 或 1")
        @Max(value = 1, message = "priority 只能为 0 或 1")
        Integer priority
) {
}

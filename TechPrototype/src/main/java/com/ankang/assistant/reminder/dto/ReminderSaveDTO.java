package com.ankang.assistant.reminder.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.time.LocalDateTime;

public record ReminderSaveDTO(
        @Size(max = 36) String clientReminderId,
        @NotBlank @Size(max = 128) String title,
        String type,
        @Size(max = 255) String description,
        @Size(max = 255) String remark,
        LocalDateTime remindAt,
        String remindTime,
        String repeatType,
        Boolean enabled
) {
}

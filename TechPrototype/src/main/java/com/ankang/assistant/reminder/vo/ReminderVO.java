package com.ankang.assistant.reminder.vo;

import java.time.LocalDateTime;

public record ReminderVO(
        Long id,
        String clientReminderId,
        String title,
        String type,
        String description,
        String remark,
        LocalDateTime remindAt,
        String remindTime,
        String repeatType,
        Boolean enabled,
        Boolean completed
) {
}

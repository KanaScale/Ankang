package com.ankang.assistant.user.dto;

public record HealthGoalUpdateDTO(
        String stepsTarget,
        String stepsNote,
        String sleepTarget,
        String sleepNote,
        String bloodPressureTarget,
        String bloodPressureNote
) {
}

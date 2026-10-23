package com.ankang.assistant.user.vo;

public record HealthGoalVO(
        String stepsTarget,
        String stepsNote,
        String sleepTarget,
        String sleepNote,
        String bloodPressureTarget,
        String bloodPressureNote
) {
}

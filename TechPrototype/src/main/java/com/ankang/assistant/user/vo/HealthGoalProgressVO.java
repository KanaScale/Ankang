package com.ankang.assistant.user.vo;

public record HealthGoalProgressVO(
        HealthGoalProgressItemVO steps,
        HealthGoalProgressItemVO sleep,
        HealthGoalProgressItemVO bloodPressure
) {
}

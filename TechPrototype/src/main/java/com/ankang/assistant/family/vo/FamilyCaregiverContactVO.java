package com.ankang.assistant.family.vo;

public record FamilyCaregiverContactVO(
        Long caregiverUserId,
        String name,
        String relationType,
        String phone
) {
}

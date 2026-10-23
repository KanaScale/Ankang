package com.ankang.assistant.family.vo;

import java.util.List;

public record FamilyPermissionVO(
        Long patientUserId,
        Long caregiverUserId,
        List<String> permissions,
        String status
) {
}

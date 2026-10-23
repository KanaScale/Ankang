package com.ankang.assistant.emergency.vo;

public record EmergencyContactVO(
        Long id,
        String clientContactId,
        String name,
        String relation,
        String relationship,
        String phone,
        Integer priority,
        String phoneE164,
        String phoneType,
        Boolean smsCapable
) {
}

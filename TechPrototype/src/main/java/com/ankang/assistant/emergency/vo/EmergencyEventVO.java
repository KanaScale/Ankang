package com.ankang.assistant.emergency.vo;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

public record EmergencyEventVO(
        Long id,
        Long eventId,
        LocalDateTime createdAt,
        BigDecimal latitude,
        BigDecimal longitude,
        String address,
        String status,
        String message,
        Integer contactsNotified,
        String clientEventId,
        LocalDateTime triggeredAt,
        BigDecimal accuracyMeters,
        String locationSource,
        List<DispatchAttemptVO> attempts
) {
}

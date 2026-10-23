package com.ankang.assistant.emergency.dto;

import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public record SosCreateDTO(
        @Size(max = 36) String clientEventId,
        LocalDateTime triggeredAt,
        BigDecimal latitude,
        BigDecimal longitude,
        BigDecimal accuracyMeters,
        @Size(max = 32) String locationSource,
        @Size(max = 255) String address,
        @Size(max = 255) String message
) {
    public SosCreateDTO(BigDecimal latitude, BigDecimal longitude, String address, String message) {
        this(null, null, latitude, longitude, null, null, address, message);
    }
}

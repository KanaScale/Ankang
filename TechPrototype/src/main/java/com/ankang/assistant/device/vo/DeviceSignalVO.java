package com.ankang.assistant.device.vo;

import java.time.LocalDateTime;

public record DeviceSignalVO(
        String signalId,
        String signalType,
        String status,
        String message,
        LocalDateTime sentAt
) {
}

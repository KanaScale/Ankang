package com.ankang.assistant.device.dto;

import jakarta.validation.constraints.Size;

public record DeviceSignalDTO(
        @Size(max = 32) String signalType,
        @Size(max = 255) String payload
) {
}

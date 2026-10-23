package com.ankang.assistant.device.vo;

import java.time.LocalDateTime;
import java.util.List;

public record DeviceSyncVO(
        Long id,
        String deviceName,
        String deviceType,
        String provider,
        String bindStatus,
        LocalDateTime lastSyncAt,
        Integer battery,
        String connectionStatus,
        List<DeviceMetricVO> metrics,
        DeviceSignalVO lastSignal,
        List<Long> writtenRecordIds,
        List<String> writtenRecordTypes,
        DeviceRiskAlertVO riskAlert
) {
}

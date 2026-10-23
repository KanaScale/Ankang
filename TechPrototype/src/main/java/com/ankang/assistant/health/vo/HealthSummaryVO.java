package com.ankang.assistant.health.vo;

import java.util.List;

public record HealthSummaryVO(
        Integer healthScore,
        String status,
        List<MetricVO> metrics
) {
    public record MetricVO(
            String type,
            String name,
            String value,
            String unit,
            String status,
            String trend
    ) {
    }
}

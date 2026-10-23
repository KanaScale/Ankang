package com.ankang.assistant.health.vo;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public record HealthTrendVO(
        String type,
        String range,
        List<PointVO> points,
        BigDecimal avg,
        BigDecimal max,
        BigDecimal min,
        Integer abnormalCount
) {
    public record PointVO(
            LocalDate date,
            BigDecimal value
    ) {
    }
}

package com.ankang.assistant.report.vo;

import java.util.Map;

public record WeeklyHealthReportVO(
        String weekStart,
        String weekEnd,
        String summary,
        Map<String, Object> indicators
) {
}

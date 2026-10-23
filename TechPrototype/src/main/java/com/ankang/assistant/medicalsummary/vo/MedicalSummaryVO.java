package com.ankang.assistant.medicalsummary.vo;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

/**
 * 面向就医沟通的只读结构化摘要。
 *
 * <p>仅汇总系统中已有的客观记录和档案字段，不包含用户自述，也不生成诊断结论。</p>
 */
public record MedicalSummaryVO(
        LocalDateTime generatedAt,
        LocalDate rangeStart,
        LocalDate rangeEnd,
        int rangeDays,
        PatientVO patient,
        HealthProfileSnapshotVO healthProfile,
        List<MetricSummaryVO> metrics,
        List<RiskEventSummaryVO> riskEvents,
        MedicationSummaryVO medication,
        List<DataSourceVO> dataSources,
        int totalRecordCount,
        int abnormalRecordCount,
        String disclaimer
) {
    public record PatientVO(
            String displayName,
            Integer age,
            String gender
    ) {
    }

    public record HealthProfileSnapshotVO(
            BigDecimal height,
            BigDecimal weight,
            BigDecimal bmi,
            List<String> chronicDiseases,
            String allergies,
            String medicalHistory,
            String device
    ) {
    }

    public record MetricSummaryVO(
            String type,
            String label,
            String unit,
            int recordCount,
            String latestValue,
            LocalDateTime latestAt,
            String averageValue,
            String minimumValue,
            String maximumValue,
            int abnormalCount,
            String latestStatus
    ) {
    }

    public record RiskEventSummaryVO(
            String eventId,
            String riskLevel,
            Integer riskScore,
            String summary,
            List<String> reasons,
            LocalDateTime occurredAt
    ) {
    }

    public record MedicationSummaryVO(
            int enabledCount,
            int completedCurrentCycleCount,
            List<MedicationReminderVO> reminders
    ) {
    }

    public record MedicationReminderVO(
            String title,
            String schedule,
            String repeatType,
            boolean completedCurrentCycle
    ) {
    }

    public record DataSourceVO(
            String source,
            String label,
            int recordCount
    ) {
    }
}

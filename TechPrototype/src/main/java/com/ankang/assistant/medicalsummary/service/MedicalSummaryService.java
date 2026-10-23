package com.ankang.assistant.medicalsummary.service;

import com.ankang.assistant.config.SecurityUtils;
import com.ankang.assistant.eventmesh.entity.HealthEvent;
import com.ankang.assistant.eventmesh.mapper.HealthEventMapper;
import com.ankang.assistant.health.entity.HealthRecord;
import com.ankang.assistant.health.mapper.HealthRecordMapper;
import com.ankang.assistant.medicalsummary.vo.MedicalSummaryVO;
import com.ankang.assistant.reminder.entity.Reminder;
import com.ankang.assistant.reminder.mapper.ReminderMapper;
import com.ankang.assistant.user.vo.HealthProfileVO;
import com.ankang.assistant.user.vo.UserProfileVO;
import com.ankang.assistant.user.service.UserService;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.time.temporal.WeekFields;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
public class MedicalSummaryService {

    private static final int DEFAULT_RANGE_DAYS = 14;
    private static final int MIN_RANGE_DAYS = 7;
    private static final int MAX_RANGE_DAYS = 90;
    private static final int MAX_RISK_EVENTS = 5;
    private static final DateTimeFormatter TIME_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm");
    private static final List<String> METRIC_ORDER = List.of(
            "blood_pressure", "blood_glucose", "heart_rate", "weight", "steps", "sleep_hours", "other"
    );
    private static final String DISCLAIMER =
            "本页由用户日常记录自动整理，仅用于就医沟通，不代表医生诊断；设备及手工录入数据可能存在误差。";

    private final UserService userService;
    private final HealthRecordMapper healthRecordMapper;
    private final ReminderMapper reminderMapper;
    private final HealthEventMapper healthEventMapper;
    private final ObjectMapper objectMapper;

    public MedicalSummaryService(
            UserService userService,
            HealthRecordMapper healthRecordMapper,
            ReminderMapper reminderMapper,
            HealthEventMapper healthEventMapper,
            ObjectMapper objectMapper
    ) {
        this.userService = userService;
        this.healthRecordMapper = healthRecordMapper;
        this.reminderMapper = reminderMapper;
        this.healthEventMapper = healthEventMapper;
        this.objectMapper = objectMapper;
    }

    public MedicalSummaryVO generate(Integer requestedDays) {
        int days = normalizeDays(requestedDays);
        Long userId = SecurityUtils.currentUserId();
        LocalDate rangeEnd = LocalDate.now();
        LocalDate rangeStart = rangeEnd.minusDays(days - 1L);
        LocalDateTime startTime = rangeStart.atStartOfDay();
        LocalDateTime endExclusive = rangeEnd.plusDays(1).atStartOfDay();

        UserProfileVO user = userService.getProfileByUserId(userId);
        HealthProfileVO profile = userService.getHealthProfileByUserId(userId);
        List<HealthRecord> records = healthRecordMapper.selectList(new LambdaQueryWrapper<HealthRecord>()
                .eq(HealthRecord::getUserId, userId)
                .ge(HealthRecord::getRecordedAt, startTime)
                .lt(HealthRecord::getRecordedAt, endExclusive)
                .orderByDesc(HealthRecord::getRecordedAt)
                .orderByDesc(HealthRecord::getId));
        List<Reminder> medicationReminders = reminderMapper.selectList(new LambdaQueryWrapper<Reminder>()
                .eq(Reminder::getUserId, userId)
                .eq(Reminder::getType, "medicine")
                .eq(Reminder::getEnabled, true)
                .orderByAsc(Reminder::getRemindAt)
                .orderByAsc(Reminder::getId));
        List<HealthEvent> riskEvents = healthEventMapper.selectList(new LambdaQueryWrapper<HealthEvent>()
                .eq(HealthEvent::getUserId, userId)
                .ge(HealthEvent::getOccurredAt, startTime)
                .lt(HealthEvent::getOccurredAt, endExclusive)
                .in(HealthEvent::getRiskLevel, List.of("elevated", "high"))
                .orderByDesc(HealthEvent::getOccurredAt)
                .orderByDesc(HealthEvent::getId)
                .last("LIMIT " + MAX_RISK_EVENTS));

        int abnormalCount = (int) records.stream()
                .filter(record -> !"normal".equals(record.getStatus()))
                .count();
        return new MedicalSummaryVO(
                LocalDateTime.now(),
                rangeStart,
                rangeEnd,
                days,
                new MedicalSummaryVO.PatientVO(displayName(user), user.age(), user.gender()),
                toProfileSnapshot(profile),
                summarizeMetrics(records),
                riskEvents.stream().map(this::toRiskEvent).toList(),
                summarizeMedication(medicationReminders),
                summarizeSources(records),
                records.size(),
                abnormalCount,
                DISCLAIMER
        );
    }

    private int normalizeDays(Integer requestedDays) {
        int days = requestedDays == null ? DEFAULT_RANGE_DAYS : requestedDays;
        if (days < MIN_RANGE_DAYS || days > MAX_RANGE_DAYS) {
            throw new IllegalArgumentException("就医摘要时间范围必须在 7 到 90 天之间");
        }
        return days;
    }

    private String displayName(UserProfileVO user) {
        if (hasText(user.nickname())) {
            return user.nickname().trim();
        }
        if (hasText(user.username())) {
            return user.username().trim();
        }
        return "未填写";
    }

    private MedicalSummaryVO.HealthProfileSnapshotVO toProfileSnapshot(HealthProfileVO profile) {
        return new MedicalSummaryVO.HealthProfileSnapshotVO(
                profile.height(),
                profile.weight(),
                profile.bmi(),
                profile.chronicDiseases() == null ? List.of() : profile.chronicDiseases(),
                profile.allergies(),
                profile.medicalHistory(),
                profile.device()
        );
    }

    private List<MedicalSummaryVO.MetricSummaryVO> summarizeMetrics(List<HealthRecord> records) {
        Map<String, List<HealthRecord>> byType = new LinkedHashMap<>();
        records.forEach(record -> byType.computeIfAbsent(record.getType(), ignored -> new ArrayList<>()).add(record));
        return METRIC_ORDER.stream()
                .filter(byType::containsKey)
                .map(type -> summarizeMetric(type, byType.get(type)))
                .toList();
    }

    private MedicalSummaryVO.MetricSummaryVO summarizeMetric(String type, List<HealthRecord> records) {
        List<HealthRecord> sorted = records.stream()
                .sorted(Comparator.comparing(HealthRecord::getRecordedAt).reversed())
                .toList();
        HealthRecord latest = sorted.get(0);
        int abnormalCount = (int) sorted.stream()
                .filter(record -> !"normal".equals(record.getStatus()))
                .count();

        if ("blood_pressure".equals(type)) {
            List<BigDecimal> systolic = sorted.stream()
                    .map(HealthRecord::getSystolic)
                    .filter(value -> value != null)
                    .map(BigDecimal::valueOf)
                    .toList();
            List<BigDecimal> diastolic = sorted.stream()
                    .map(HealthRecord::getDiastolic)
                    .filter(value -> value != null)
                    .map(BigDecimal::valueOf)
                    .toList();
            return new MedicalSummaryVO.MetricSummaryVO(
                    type, metricLabel(type), "mmHg", sorted.size(), displayValue(latest), latest.getRecordedAt(),
                    pairStatistic(systolic, diastolic, Statistic.AVERAGE),
                    pairStatistic(systolic, diastolic, Statistic.MINIMUM),
                    pairStatistic(systolic, diastolic, Statistic.MAXIMUM),
                    abnormalCount, latest.getStatus()
            );
        }

        List<BigDecimal> values = sorted.stream()
                .map(this::singleValue)
                .filter(value -> value != null)
                .toList();
        return new MedicalSummaryVO.MetricSummaryVO(
                type, metricLabel(type), latest.getUnit(), sorted.size(), displayValue(latest), latest.getRecordedAt(),
                statistic(values, Statistic.AVERAGE),
                statistic(values, Statistic.MINIMUM),
                statistic(values, Statistic.MAXIMUM),
                abnormalCount, latest.getStatus()
        );
    }

    private String pairStatistic(List<BigDecimal> first, List<BigDecimal> second, Statistic statistic) {
        if (first.isEmpty() || second.isEmpty()) {
            return null;
        }
        return statistic(first, statistic) + "/" + statistic(second, statistic);
    }

    private String statistic(List<BigDecimal> values, Statistic statistic) {
        if (values.isEmpty()) {
            return null;
        }
        BigDecimal result = switch (statistic) {
            case AVERAGE -> values.stream().reduce(BigDecimal.ZERO, BigDecimal::add)
                    .divide(BigDecimal.valueOf(values.size()), 1, RoundingMode.HALF_UP);
            case MINIMUM -> values.stream().min(Comparator.naturalOrder()).orElse(BigDecimal.ZERO);
            case MAXIMUM -> values.stream().max(Comparator.naturalOrder()).orElse(BigDecimal.ZERO);
        };
        return result.stripTrailingZeros().toPlainString();
    }

    private String displayValue(HealthRecord record) {
        if ("blood_pressure".equals(record.getType())
                && record.getSystolic() != null
                && record.getDiastolic() != null) {
            return record.getSystolic() + "/" + record.getDiastolic();
        }
        BigDecimal value = singleValue(record);
        return value == null ? "--" : value.stripTrailingZeros().toPlainString();
    }

    private BigDecimal singleValue(HealthRecord record) {
        return record.getValue() != null ? record.getValue() : record.getValue1();
    }

    private MedicalSummaryVO.RiskEventSummaryVO toRiskEvent(HealthEvent event) {
        return new MedicalSummaryVO.RiskEventSummaryVO(
                event.getEventId(),
                event.getRiskLevel(),
                event.getRiskScore(),
                event.getSummary(),
                parseReasons(event.getReasonsJson()),
                event.getOccurredAt()
        );
    }

    private List<String> parseReasons(String reasonsJson) {
        if (!hasText(reasonsJson)) {
            return List.of();
        }
        try {
            return objectMapper.readValue(reasonsJson, new TypeReference<>() { });
        } catch (JsonProcessingException ignored) {
            return List.of();
        }
    }

    private MedicalSummaryVO.MedicationSummaryVO summarizeMedication(List<Reminder> reminders) {
        List<MedicalSummaryVO.MedicationReminderVO> items = reminders.stream()
                .map(reminder -> new MedicalSummaryVO.MedicationReminderVO(
                        reminder.getTitle(),
                        reminder.getRemindAt() == null ? "--" : reminder.getRemindAt().format(TIME_FORMATTER),
                        reminder.getRepeatType(),
                        completedInCurrentCycle(reminder)
                ))
                .toList();
        int completed = (int) reminders.stream().filter(this::completedInCurrentCycle).count();
        return new MedicalSummaryVO.MedicationSummaryVO(reminders.size(), completed, items);
    }

    private boolean completedInCurrentCycle(Reminder reminder) {
        if ("once".equals(reminder.getRepeatType())) {
            return Boolean.TRUE.equals(reminder.getCompleted());
        }
        if (reminder.getLastCompletedDate() == null) {
            return false;
        }
        LocalDate today = LocalDate.now();
        if ("weekly".equals(reminder.getRepeatType())) {
            WeekFields weekFields = WeekFields.ISO;
            LocalDate completedDate = reminder.getLastCompletedDate();
            return completedDate.get(weekFields.weekBasedYear()) == today.get(weekFields.weekBasedYear())
                    && completedDate.get(weekFields.weekOfWeekBasedYear())
                    == today.get(weekFields.weekOfWeekBasedYear());
        }
        return reminder.getLastCompletedDate().equals(today);
    }

    private List<MedicalSummaryVO.DataSourceVO> summarizeSources(List<HealthRecord> records) {
        Map<String, Integer> counts = new LinkedHashMap<>();
        records.forEach(record -> {
            String source = hasText(record.getSource()) ? record.getSource().trim() : "unknown";
            counts.merge(source, 1, Integer::sum);
        });
        return counts.entrySet().stream()
                .map(entry -> new MedicalSummaryVO.DataSourceVO(
                        entry.getKey(), sourceLabel(entry.getKey()), entry.getValue()))
                .toList();
    }

    private String metricLabel(String type) {
        return switch (type) {
            case "blood_pressure" -> "血压";
            case "blood_glucose" -> "血糖";
            case "heart_rate" -> "心率";
            case "weight" -> "体重";
            case "steps" -> "步数";
            case "sleep_hours" -> "睡眠时长";
            default -> "其他";
        };
    }

    private String sourceLabel(String source) {
        return switch (source) {
            case "smart_band", "band", "wearable" -> "智能手环";
            case "manual" -> "用户手工录入";
            case "device" -> "健康设备";
            default -> "其他来源";
        };
    }

    private boolean hasText(String value) {
        return value != null && !value.isBlank();
    }

    private enum Statistic {
        AVERAGE,
        MINIMUM,
        MAXIMUM
    }
}

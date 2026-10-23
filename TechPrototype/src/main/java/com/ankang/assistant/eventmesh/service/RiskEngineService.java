package com.ankang.assistant.eventmesh.service;

import com.ankang.assistant.eventmesh.vo.RiskAssessment;
import com.ankang.assistant.health.entity.HealthRecord;
import com.ankang.assistant.health.mapper.HealthRecordMapper;
import com.ankang.assistant.reminder.entity.Reminder;
import com.ankang.assistant.reminder.mapper.ReminderMapper;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * 混合健康风险引擎：医学规则负责安全底线，个体模型负责发现范围内异常、
 * 趋势突变和多指标联合异常。
 */
@Service
public class RiskEngineService {

    private static final Set<String> MEDICATION_TYPES = Set.of("medicine", "medication", "drug", "服药", "用药");

    private final HealthRecordMapper healthRecordMapper;
    private final ReminderMapper reminderMapper;
    private final AdaptiveRiskAnalyzer adaptiveRiskAnalyzer;

    public RiskEngineService(
            HealthRecordMapper healthRecordMapper,
            ReminderMapper reminderMapper,
            AdaptiveRiskAnalyzer adaptiveRiskAnalyzer
    ) {
        this.healthRecordMapper = healthRecordMapper;
        this.reminderMapper = reminderMapper;
        this.adaptiveRiskAnalyzer = adaptiveRiskAnalyzer;
    }

    public RiskAssessment assess(Long userId) {
        return assess(userId, null);
    }

    /**
     * 评估一次健康记录事件。本次录入作为主指标，最近 24 小时其他类型的最新记录
     * 作为关联指标，避免弹窗内容与用户刚输入的数据对应不清。
     */
    public RiskAssessment assess(Long userId, Long healthRecordId) {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime baselineSince = now.minusDays(30);
        LocalDateTime recentSince = now.minusHours(24);
        List<HealthRecord> records = healthRecordMapper.selectList(new LambdaQueryWrapper<HealthRecord>()
                .eq(HealthRecord::getUserId, userId)
                .ge(HealthRecord::getRecordedAt, baselineSince)
                .orderByDesc(HealthRecord::getRecordedAt)
                .orderByDesc(HealthRecord::getId));

        Map<String, HealthRecord> latest = new LinkedHashMap<>();
        records.stream()
                .filter(record -> record.getRecordedAt() != null
                        && !record.getRecordedAt().isBefore(recentSince))
                .forEach(record -> latest.putIfAbsent(record.getType(), record));

        HealthRecord current = findCurrentRecord(userId, healthRecordId);
        if (current != null) {
            // 即使用户补录了较早的测量时间，也以触发本事件的记录作为本次主指标。
            latest.put(current.getType(), current);
        }

        int score = 0;
        int currentRiskScore = 0;
        List<String> reasons = new ArrayList<>();

        if (current != null) {
            RiskSignal currentSignal = signalFor(current);
            currentRiskScore = currentSignal.score();
            score += currentRiskScore;
            if (currentSignal.hasReason()) {
                reasons.add("本次录入：" + currentSignal.reason());
            }
        }
        for (HealthRecord record : latest.values()) {
            if (current != null && current.getType().equals(record.getType())) {
                continue;
            }
            RiskSignal relatedSignal = signalFor(record);
            score += relatedSignal.score();
            if (relatedSignal.hasReason()) {
                reasons.add((current == null ? "" : "近 24 小时关联数据：") + relatedSignal.reason());
            }
        }

        AdaptiveRiskResult adaptive = adaptiveRiskAnalyzer.analyze(current, latest, records);
        score += adaptive.score();
        currentRiskScore += adaptive.currentScore();
        reasons.addAll(adaptive.reasons());

        if (hasIncompleteMedicationReminder(userId)) {
            score += 10;
            reasons.add("今日服药提醒尚未完成");
        }

        score = Math.min(score, 100);
        String level = score >= 70 || currentRiskScore >= 60
                ? "high"
                : score >= 35 || currentRiskScore > 0 || adaptive.score() > 0
                ? "elevated"
                : "normal";
        String summary = buildSummary(current, level, score);
        if (reasons.isEmpty()) {
            reasons.add("最近 24 小时指标未触发医学规则或个体异常模型");
        }
        return new RiskAssessment(level, score, summary, List.copyOf(reasons));
    }

    private HealthRecord findCurrentRecord(Long userId, Long healthRecordId) {
        if (healthRecordId == null) {
            return null;
        }
        HealthRecord record = healthRecordMapper.selectById(healthRecordId);
        return record != null && userId.equals(record.getUserId()) ? record : null;
    }

    private RiskSignal signalFor(HealthRecord record) {
        if (record == null || record.getType() == null) {
            return RiskSignal.none();
        }
        if ("blood_pressure".equals(record.getType())
                && record.getSystolic() != null && record.getDiastolic() != null) {
            int systolic = record.getSystolic();
            int diastolic = record.getDiastolic();
            String reading = systolic + "/" + diastolic + " mmHg";
            if (systolic >= 180 || diastolic >= 120) {
                return new RiskSignal(60, "血压达到重度异常范围（" + reading + "）");
            }
            if (systolic >= 160 || diastolic >= 100) {
                return new RiskSignal(45, "血压明显偏高（" + reading + "）");
            }
            if (systolic >= 140 || diastolic >= 90) {
                return new RiskSignal(25, "血压高于建议范围（" + reading + "）");
            }
            if (systolic < 90 || diastolic < 60) {
                return new RiskSignal(25, "血压低于建议范围（" + reading + "）");
            }
            return RiskSignal.none();
        }

        BigDecimal value = valueOf(record);
        if (value == null) {
            return RiskSignal.none();
        }
        if ("heart_rate".equals(record.getType())) {
            String reading = plain(value) + " bpm";
            if (value.compareTo(new BigDecimal("120")) > 0 || value.compareTo(new BigDecimal("50")) < 0) {
                return new RiskSignal(40, "心率处于明显异常状态（" + reading + "）");
            }
            if (value.compareTo(new BigDecimal("100")) > 0 || value.compareTo(new BigDecimal("60")) < 0) {
                return new RiskSignal(25, "心率处于偏快或偏慢状态（" + reading + "）");
            }
        }
        if ("blood_glucose".equals(record.getType())) {
            String reading = plain(value) + " mmol/L";
            if (value.compareTo(new BigDecimal("11.1")) >= 0) {
                return new RiskSignal(30, "血糖明显偏高（" + reading + "）");
            }
            if (value.compareTo(new BigDecimal("6.1")) > 0) {
                return new RiskSignal(20, "血糖高于建议范围（" + reading + "）");
            }
            if (value.compareTo(new BigDecimal("3.9")) < 0) {
                return new RiskSignal(20, "血糖低于建议范围（" + reading + "）");
            }
        }
        return RiskSignal.none();
    }

    private String buildSummary(HealthRecord current, String level, int score) {
        if (current == null) {
            return switch (level) {
                case "high" -> "检测到较高健康风险，建议立即关注并评估是否进入 SOS";
                case "elevated" -> "检测到健康指标异常，建议查看趋势并咨询 Agent";
                default -> "当前未检测到明显健康风险";
            };
        }
        String reading = describe(current);
        return switch (level) {
            case "high" -> "本次录入" + reading + "；结合最近 24 小时数据，风险评分为 "
                    + score + " 分，建议立即关注";
            case "elevated" -> "本次录入" + reading + "；风险评分为 " + score
                    + " 分，建议复测并查看趋势";
            default -> "本次录入" + reading + "，当前未触发医学规则或个体异常模型";
        };
    }

    private String describe(HealthRecord record) {
        return switch (record.getType()) {
            case "blood_pressure" -> "血压 " + record.getSystolic() + "/" + record.getDiastolic() + " mmHg";
            case "heart_rate" -> "心率 " + plain(valueOf(record)) + " bpm";
            case "blood_glucose" -> "血糖 " + plain(valueOf(record)) + " mmol/L";
            case "weight" -> "体重 " + plain(valueOf(record)) + " kg";
            default -> "健康指标 " + (valueOf(record) == null ? "--" : plain(valueOf(record)));
        };
    }

    private boolean hasIncompleteMedicationReminder(Long userId) {
        LocalDate today = LocalDate.now();
        return reminderMapper.selectList(new LambdaQueryWrapper<Reminder>()
                        .eq(Reminder::getUserId, userId)
                        .eq(Reminder::getEnabled, true))
                .stream()
                .filter(reminder -> reminder.getType() != null
                        && MEDICATION_TYPES.contains(reminder.getType().trim().toLowerCase()))
                .anyMatch(reminder -> {
                    if ("once".equals(reminder.getRepeatType())) {
                        return !Boolean.TRUE.equals(reminder.getCompleted())
                                && (reminder.getRemindAt() == null || !reminder.getRemindAt().toLocalDate().isAfter(today));
                    }
                    return !today.equals(reminder.getLastCompletedDate());
                });
    }

    private BigDecimal valueOf(HealthRecord record) {
        if (record == null) {
            return null;
        }
        return record.getValue() != null ? record.getValue() : record.getValue1();
    }

    private String plain(BigDecimal value) {
        return value.stripTrailingZeros().toPlainString();
    }

    private record RiskSignal(int score, String reason) {
        static RiskSignal none() {
            return new RiskSignal(0, null);
        }

        boolean hasReason() {
            return reason != null && !reason.isBlank();
        }
    }
}

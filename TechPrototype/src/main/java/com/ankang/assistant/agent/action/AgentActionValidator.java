package com.ankang.assistant.agent.action;

import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;
import java.util.Set;

@Component
public class AgentActionValidator {

    private static final DateTimeFormatter DATE_TIME_FORMATTER =
            DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
    private static final Set<String> REMINDER_TYPES = Set.of(
            "medicine", "bloodPressure", "bloodSugar", "checkup", "other"
    );
    private static final Set<String> REPEAT_TYPES = Set.of("once", "daily", "weekly");

    public void validateForCreation(AgentActionRequest request, String actorRole) {
        if (request == null || request.actionType() == null) {
            throw new IllegalArgumentException("Agent Action 类型不能为空");
        }
        validateRolePermission(request.actionType(), actorRole);
        validatePayload(request.actionType(), request.payload());
    }

    public void validateForExecution(
            AgentActionType actionType,
            Map<String, Object> payload,
            AgentActionExecutionContext context
    ) {
        validateRolePermission(actionType, context.actorRole());
        validatePayload(actionType, payload);
    }

    private void validateRolePermission(AgentActionType actionType, String actorRole) {
        if (!"CAREGIVER".equals(actorRole)) {
            return;
        }
        if (actionType == AgentActionType.RECORD_HEALTH_DATA || actionType == AgentActionType.CREATE_HEALTH_PLAN) {
            throw new IllegalArgumentException("家属版 Agent 不能直接修改被照护者健康数据或提醒");
        }
    }

    private void validatePayload(AgentActionType actionType, Map<String, Object> payload) {
        Map<String, Object> safePayload = payload == null ? Map.of() : payload;
        switch (actionType) {
            case RECORD_HEALTH_DATA -> validateHealthPayload(safePayload);
            case CREATE_HEALTH_PLAN -> validatePlanPayload(safePayload);
            case SEARCH_NEARBY_HOSPITALS -> validateCoordinatesIfPresent(safePayload);
            case PREPARE_SOS_PLAN -> validateCoordinatesIfPresent(safePayload);
            case EVALUATE_HEALTH_RISK, NOTIFY_FAMILY_PREVIEW -> {
            }
        }
    }

    private void validateHealthPayload(Map<String, Object> payload) {
        boolean hasAny = false;
        Integer systolic = integer(payload.get("systolic"));
        Integer diastolic = integer(payload.get("diastolic"));
        if (systolic != null || diastolic != null) {
            hasAny = true;
            if (systolic == null || diastolic == null) {
                throw new IllegalArgumentException("血压记录必须同时包含收缩压和舒张压");
            }
            if (systolic < 40 || systolic > 300 || diastolic < 30 || diastolic > 200 || systolic <= diastolic) {
                throw new IllegalArgumentException("血压数值超出合理范围");
            }
        }
        BigDecimal heartRate = decimal(payload.get("heartRate"));
        if (heartRate != null) {
            hasAny = true;
            requireRange(heartRate, "30", "220", "心率数值超出合理范围");
        }
        BigDecimal bloodGlucose = decimal(payload.get("bloodGlucose"));
        if (bloodGlucose != null) {
            hasAny = true;
            requireRange(bloodGlucose, "1", "40", "血糖数值超出合理范围");
        }
        BigDecimal weight = decimal(payload.get("weight"));
        if (weight != null) {
            hasAny = true;
            requireRange(weight, "20", "300", "体重数值超出合理范围");
        }
        if (!hasAny) {
            throw new IllegalArgumentException("未识别到可录入的健康数据");
        }
        Object recordedAt = payload.get("recordedAt");
        if (recordedAt instanceof String text && !text.isBlank()) {
            LocalDateTime time = parseDateTime(text);
            if (time.isAfter(LocalDateTime.now().plusMinutes(5))) {
                throw new IllegalArgumentException("记录时间不能晚于当前时间");
            }
        }
    }

    private void validatePlanPayload(Map<String, Object> payload) {
        Object rawReminders = payload.get("reminders");
        if (!(rawReminders instanceof List<?> reminders)) {
            return;
        }
        for (Object rawReminder : reminders) {
            if (!(rawReminder instanceof Map<?, ?> reminder)) {
                throw new IllegalArgumentException("提醒计划格式不正确");
            }
            String title = string(reminder.get("title"));
            if (title.isBlank() || title.length() > 128) {
                throw new IllegalArgumentException("提醒标题不能为空且不能超过 128 字");
            }
            String type = string(reminder.get("type"));
            if (!type.isBlank() && !REMINDER_TYPES.contains(type)) {
                throw new IllegalArgumentException("不支持的提醒类型: " + type);
            }
            String repeatType = string(reminder.get("repeatType"));
            if (!repeatType.isBlank() && !REPEAT_TYPES.contains(repeatType)) {
                throw new IllegalArgumentException("不支持的重复类型: " + repeatType);
            }
            String remindTime = string(reminder.get("remindTime"));
            if (!remindTime.isBlank() && !remindTime.matches("([01]\\d|2[0-3]):[0-5]\\d")) {
                throw new IllegalArgumentException("提醒时间格式应为 HH:mm");
            }
            Integer dayOfWeek = integer(reminder.get("dayOfWeek"));
            if (dayOfWeek != null && (dayOfWeek < 1 || dayOfWeek > 7)) {
                throw new IllegalArgumentException("每周提醒的 dayOfWeek 必须在 1 到 7 之间");
            }
        }
    }

    private void validateCoordinatesIfPresent(Map<String, Object> payload) {
        BigDecimal latitude = decimal(payload.get("latitude"));
        BigDecimal longitude = decimal(payload.get("longitude"));
        if (latitude == null && longitude == null) {
            return;
        }
        if (latitude == null || longitude == null) {
            throw new IllegalArgumentException("经纬度必须同时提供");
        }
        requireRange(latitude, "-90", "90", "latitude 必须在 -90 到 90 之间");
        requireRange(longitude, "-180", "180", "longitude 必须在 -180 到 180 之间");
    }

    private void requireRange(BigDecimal value, String min, String max, String message) {
        if (value.compareTo(new BigDecimal(min)) < 0 || value.compareTo(new BigDecimal(max)) > 0) {
            throw new IllegalArgumentException(message);
        }
    }

    private LocalDateTime parseDateTime(String text) {
        try {
            return LocalDateTime.parse(text, DATE_TIME_FORMATTER);
        } catch (RuntimeException ignored) {
            return LocalDateTime.parse(text.replaceFirst(" ", "T"));
        }
    }

    private Integer integer(Object value) {
        if (value instanceof Integer integer) {
            return integer;
        }
        if (value instanceof Number number) {
            return number.intValue();
        }
        if (value instanceof String text && !text.isBlank()) {
            return Integer.parseInt(text);
        }
        return null;
    }

    private BigDecimal decimal(Object value) {
        if (value instanceof BigDecimal decimal) {
            return decimal;
        }
        if (value instanceof Number number) {
            return BigDecimal.valueOf(number.doubleValue());
        }
        if (value instanceof String text && !text.isBlank()) {
            return new BigDecimal(text);
        }
        return null;
    }

    private String string(Object value) {
        return value == null ? "" : value.toString().trim();
    }
}

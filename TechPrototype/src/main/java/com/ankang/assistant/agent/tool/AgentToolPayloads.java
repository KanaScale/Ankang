package com.ankang.assistant.agent.tool;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;

final class AgentToolPayloads {

    private static final DateTimeFormatter DATE_TIME_FORMATTER =
            DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    private AgentToolPayloads() {
    }

    static String string(Map<?, ?> payload, String key) {
        Object value = payload == null ? null : payload.get(key);
        return value == null ? "" : value.toString().trim();
    }

    static Integer integer(Map<?, ?> payload, String key) {
        Object value = payload == null ? null : payload.get(key);
        if (value instanceof Integer integer) {
            return integer;
        }
        if (value instanceof Number number) {
            return number.intValue();
        }
        if (value instanceof String text && !text.isBlank()) {
            return Integer.parseInt(text.trim());
        }
        return null;
    }

    static BigDecimal decimal(Map<?, ?> payload, String key) {
        Object value = payload == null ? null : payload.get(key);
        if (value instanceof BigDecimal decimal) {
            return decimal;
        }
        if (value instanceof Number number) {
            return BigDecimal.valueOf(number.doubleValue());
        }
        if (value instanceof String text && !text.isBlank()) {
            return new BigDecimal(text.trim());
        }
        return null;
    }

    static Double doubleValue(Map<?, ?> payload, String key) {
        BigDecimal value = decimal(payload, key);
        return value == null ? null : value.doubleValue();
    }

    static LocalDateTime dateTime(Map<?, ?> payload, String key) {
        String text = string(payload, key);
        if (text.isBlank()) {
            return LocalDateTime.now();
        }
        try {
            return LocalDateTime.parse(text, DATE_TIME_FORMATTER);
        } catch (RuntimeException ignored) {
            return LocalDateTime.parse(text.replaceFirst(" ", "T"));
        }
    }

    static LocalTime time(Map<?, ?> payload, String key) {
        String text = string(payload, key);
        return text.isBlank() ? LocalTime.of(8, 0) : LocalTime.parse(text);
    }

    static LocalDateTime remindAt(Map<?, ?> payload) {
        return remindAt(payload, LocalDateTime.now());
    }

    static LocalDateTime remindAt(Map<?, ?> payload, LocalDateTime now) {
        LocalTime remindTime = time(payload, "remindTime");
        String repeatType = string(payload, "repeatType");
        Integer dayOfWeek = integer(payload, "dayOfWeek");
        LocalDate date = now.toLocalDate();
        if ("weekly".equals(repeatType) && dayOfWeek != null) {
            int today = now.getDayOfWeek().getValue();
            int daysUntil = dayOfWeek - today;
            if (daysUntil < 0) {
                daysUntil += 7;
            }
            date = date.plusDays(daysUntil);
        }
        LocalDateTime candidate = date.atTime(remindTime);
        if (!candidate.isAfter(now)) {
            candidate = "weekly".equals(repeatType)
                    ? candidate.plusWeeks(1)
                    : candidate.plusDays(1);
        }
        return candidate;
    }

    static List<?> list(Map<?, ?> payload, String key) {
        Object value = payload == null ? null : payload.get(key);
        return value instanceof List<?> list ? list : List.of();
    }
}

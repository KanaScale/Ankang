package com.ankang.assistant.agent.action;

import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.DayOfWeek;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Component
public class AgentIntentParser {

    private static final DateTimeFormatter DATE_TIME_FORMATTER =
            DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
    private static final Pattern BLOOD_PRESSURE_SLASH = Pattern.compile("(\\d{2,3})\\s*/\\s*(\\d{2,3})");
    private static final Pattern BLOOD_PRESSURE_HIGH_LOW = Pattern.compile(
            "(?:高压|收缩压)[^0-9]{0,8}(\\d{2,3}).{0,24}?(?:低压|舒张压)[^0-9]{0,8}(\\d{2,3})"
    );
    private static final Pattern BLOOD_PRESSURE_LOW_HIGH = Pattern.compile(
            "(?:低压|舒张压)[^0-9]{0,8}(\\d{2,3}).{0,24}?(?:高压|收缩压)[^0-9]{0,8}(\\d{2,3})"
    );
    private static final Pattern BLOOD_PRESSURE_TEXT_NUMBERS = Pattern.compile(
            "血压[^0-9]{0,8}(\\d{2,3})[^0-9]{1,8}(\\d{2,3})"
    );
    private static final Pattern HEART_RATE = Pattern.compile("(?:心率|脉搏)[^0-9]{0,8}(\\d{2,3})");
    private static final Pattern BLOOD_GLUCOSE = Pattern.compile("血糖[^0-9]{0,8}(\\d{1,2}(?:\\.\\d+)?)");
    private static final Pattern WEIGHT = Pattern.compile("体重[^0-9]{0,8}(\\d{2,3}(?:\\.\\d+)?)");
    private static final Pattern TIME = Pattern.compile("([01]?\\d|2[0-3])\\s*(?:[:：点时])\\s*([0-5]\\d)?");
    private static final Pattern WEEKDAY = Pattern.compile("(?:每周|周|星期|礼拜)([一二三四五六日天1-7])");
    private static final Pattern COORDINATES = Pattern.compile(
            "(?:纬度|lat(?:itude)?)[^0-9\\-]{0,12}(-?\\d{1,2}(?:\\.\\d+)?).*?"
                    + "(?:经度|lng|lon(?:gitude)?)[^0-9\\-]{0,12}(-?\\d{1,3}(?:\\.\\d+)?)",
            Pattern.CASE_INSENSITIVE
    );

    public Optional<AgentActionRequest> parse(String message) {
        if (message == null || message.isBlank()) {
            return Optional.empty();
        }
        String text = message.trim();

        Optional<AgentActionRequest> record = parseRecordHealthData(text);
        if (record.isPresent()) {
            return record;
        }
        Optional<AgentActionRequest> plan = parseCreateHealthPlan(text);
        if (plan.isPresent()) {
            return plan;
        }
        if (containsAny(text, "风险", "危险吗", "严重吗", "预警", "异常")) {
            return Optional.of(new AgentActionRequest(
                    AgentActionType.EVALUATE_HEALTH_RISK,
                    "健康风险评估",
                    "基于最近健康数据和提醒完成情况进行风险评估",
                    false,
                    Map.of("requestedAt", nowText(), "sourceText", text)
            ));
        }
        if (containsAny(text, "SOS", "sos", "急救", "救命", "不舒服", "胸痛", "呼吸困难")) {
            return Optional.of(new AgentActionRequest(
                    AgentActionType.PREPARE_SOS_PLAN,
                    "生成 SOS 预案",
                    "确认后仅生成预案，不会自动报警、拨号或通知家属",
                    true,
                    withCoordinates(text, new LinkedHashMap<>(Map.of(
                            "requestedAt", nowText(),
                            "sourceText", text
                    )))
            ));
        }
        if (containsAny(text, "通知家属", "通知家人", "联系家属", "联系家人")) {
            return Optional.of(new AgentActionRequest(
                    AgentActionType.NOTIFY_FAMILY_PREVIEW,
                    "准备通知家属",
                    "确认后仅生成通知预览，不会自动发送",
                    true,
                    Map.of("requestedAt", nowText(), "sourceText", text)
            ));
        }
        if (containsAny(text, "附近医院", "医院", "就近医院")) {
            return Optional.of(new AgentActionRequest(
                    AgentActionType.SEARCH_NEARBY_HOSPITALS,
                    "查询附近医院",
                    "根据位置查询附近医院",
                    false,
                    withCoordinates(text, new LinkedHashMap<>(Map.of(
                            "radiusMeters", 5000,
                            "keyword", "医院",
                            "sourceText", text
                    )))
            ));
        }
        return Optional.empty();
    }

    private Optional<AgentActionRequest> parseRecordHealthData(String text) {
        if (!hasRecordVerb(text) && !hasMetricWithNumber(text)) {
            return Optional.empty();
        }
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("recordedAt", recordedAt(text).format(DATE_TIME_FORMATTER));
        payload.put("source", "agent_action");
        payload.put("remark", "Agent 自然语言录入");
        payload.put("sourceText", text);

        List<String> parts = new ArrayList<>();
        int[] bloodPressure = parseBloodPressure(text);
        if (bloodPressure != null) {
            payload.put("systolic", bloodPressure[0]);
            payload.put("diastolic", bloodPressure[1]);
            parts.add("血压 " + bloodPressure[0] + "/" + bloodPressure[1]);
        }
        Matcher heartRate = HEART_RATE.matcher(text);
        if (heartRate.find()) {
            int value = Integer.parseInt(heartRate.group(1));
            payload.put("heartRate", value);
            parts.add("心率 " + value);
        }
        Matcher glucose = BLOOD_GLUCOSE.matcher(text);
        if (glucose.find()) {
            BigDecimal value = new BigDecimal(glucose.group(1));
            payload.put("bloodGlucose", value);
            payload.put("glucosePeriod", text.contains("餐后") ? "post_meal" : text.contains("空腹") ? "fasting" : "unknown");
            parts.add("血糖 " + value.stripTrailingZeros().toPlainString());
        }
        Matcher weight = WEIGHT.matcher(text);
        if (weight.find()) {
            BigDecimal value = new BigDecimal(weight.group(1));
            payload.put("weight", value);
            parts.add("体重 " + value.stripTrailingZeros().toPlainString());
        }
        if (parts.isEmpty()) {
            return Optional.empty();
        }
        return Optional.of(new AgentActionRequest(
                AgentActionType.RECORD_HEALTH_DATA,
                "确认录入健康数据",
                String.join("，", parts),
                true,
                payload
        ));
    }

    private Optional<AgentActionRequest> parseCreateHealthPlan(String text) {
        if (isReminderStatusQuestion(text)) {
            return Optional.empty();
        }
        if (!containsAny(text, "安排", "计划", "提醒", "每天", "每日", "每周", "吃药", "服药", "测血压", "测血糖", "运动")) {
            return Optional.empty();
        }
        List<Map<String, Object>> reminders = new ArrayList<>();
        String repeatType = text.contains("每天") || text.contains("每日") ? "daily"
                : text.contains("每周") ? "weekly" : "once";

        String generalTime = resolveTimeText(text);
        Integer dayOfWeek = resolveDayOfWeek(text);
        if (text.contains("血压")) {
            String time = resolveTopicTime(text, generalTime, "血压", "测血压");
            addReminderIfConcrete(reminders, "测血压", "bloodPressure", "按计划测量血压",
                    time, repeatType, dayOfWeek);
        }
        if (text.contains("血糖")) {
            String time = resolveTopicTime(text, generalTime, "血糖", "测血糖");
            addReminderIfConcrete(reminders, "测血糖", "bloodSugar", "按计划测量血糖",
                    time, repeatType, dayOfWeek);
        }
        if (text.contains("吃药") || text.contains("服药") || text.contains("药")) {
            String time = resolveTopicTime(text, generalTime, "吃药", "服药", "药");
            addReminderIfConcrete(reminders, "服药提醒", "medicine", "按医嘱服药，不自行调整剂量",
                    time, repeatType, dayOfWeek);
        }
        if (text.contains("运动")) {
            String time = resolveTopicTime(text, generalTime, "运动");
            addReminderIfConcrete(reminders, "运动计划", "other", "按身体情况进行适度运动",
                    time, repeatType, dayOfWeek);
        }

        List<String> suggestions = new ArrayList<>();
        if (reminders.isEmpty()) {
            suggestions.add("计划内容还缺少明确时间，暂不直接创建提醒");
            suggestions.add("可以补充类似“每天早上 8 点”或“每周一上午 9 点”");
        } else {
            suggestions.add("提醒创建后仍需遵医嘱执行药物相关安排");
        }
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("reminders", reminders);
        payload.put("suggestions", suggestions);
        payload.put("sourceText", text);
        return Optional.of(new AgentActionRequest(
                AgentActionType.CREATE_HEALTH_PLAN,
                reminders.isEmpty() ? "确认健康计划建议" : "确认创建健康计划",
                reminders.isEmpty()
                        ? "计划暂不包含可直接创建的明确提醒"
                        : "将创建 " + reminders.size() + " 条提醒",
                true,
                payload
        ));
    }

    private boolean isReminderStatusQuestion(String text) {
        if (!containsAny(text, "药", "吃药", "服药", "用药", "提醒")) {
            return false;
        }
        if (!containsAny(text, "是否", "有没有", "按时", "完成", "吃了吗", "服了吗", "吃过", "服过", "了吗")) {
            return false;
        }
        return !containsAny(text, "创建", "新增", "添加", "设置", "设个", "建个", "安排", "计划", "提醒我", "帮我提醒");
    }

    private void addReminderIfConcrete(
            List<Map<String, Object>> reminders,
            String title,
            String type,
            String description,
            String remindTime,
            String repeatType,
            Integer dayOfWeek
    ) {
        if (remindTime == null || remindTime.isBlank()) {
            return;
        }
        Map<String, Object> reminder = new LinkedHashMap<>();
        reminder.put("title", title);
        reminder.put("type", type);
        reminder.put("description", description);
        reminder.put("remindTime", remindTime);
        reminder.put("repeatType", repeatType);
        if ("weekly".equals(repeatType) && dayOfWeek != null) {
            reminder.put("dayOfWeek", dayOfWeek);
        }
        reminders.add(reminder);
    }

    private int[] parseBloodPressure(String text) {
        Matcher slash = BLOOD_PRESSURE_SLASH.matcher(text);
        if (slash.find()) {
            return new int[]{
                    Integer.parseInt(slash.group(1)),
                    Integer.parseInt(slash.group(2))
            };
        }
        Matcher highLow = BLOOD_PRESSURE_HIGH_LOW.matcher(text);
        if (highLow.find()) {
            return new int[]{
                    Integer.parseInt(highLow.group(1)),
                    Integer.parseInt(highLow.group(2))
            };
        }
        Matcher lowHigh = BLOOD_PRESSURE_LOW_HIGH.matcher(text);
        if (lowHigh.find()) {
            return new int[]{
                    Integer.parseInt(lowHigh.group(2)),
                    Integer.parseInt(lowHigh.group(1))
            };
        }
        Matcher textNumbers = BLOOD_PRESSURE_TEXT_NUMBERS.matcher(text);
        if (textNumbers.find()) {
            return new int[]{
                    Integer.parseInt(textNumbers.group(1)),
                    Integer.parseInt(textNumbers.group(2))
            };
        }
        return null;
    }

    private String resolveTopicTime(String text, String generalTime, String... topicKeywords) {
        for (String segment : splitPlanSegments(text)) {
            if (containsAny(segment, topicKeywords)) {
                String localTime = resolveNearestNumericTime(segment, topicKeywords);
                if (localTime != null) {
                    return localTime;
                }
                localTime = resolveNearestTimeHint(segment, topicKeywords);
                if (localTime != null) {
                    return localTime;
                }
            }
        }
        String localTime = resolveNearestNumericTime(text, topicKeywords);
        if (localTime != null) {
            return localTime;
        }
        localTime = resolveNearestTimeHint(text, topicKeywords);
        if (localTime != null) {
            return localTime;
        }
        return countTimeHints(text) <= 1 ? generalTime : null;
    }

    private List<String> splitPlanSegments(String text) {
        return Arrays.stream(text.split("[，,。；;、]"))
                .map(String::trim)
                .filter(segment -> !segment.isBlank())
                .toList();
    }

    private String topicWindow(String text, String... topicKeywords) {
        int best = -1;
        for (String keyword : topicKeywords) {
            int idx = text.indexOf(keyword);
            if (idx >= 0 && (best < 0 || idx < best)) {
                best = idx;
            }
        }
        if (best < 0) {
            return "";
        }
        int start = Math.max(0, best - 16);
        int end = Math.min(text.length(), best + 16);
        return text.substring(start, end);
    }

    private String resolveNearestNumericTime(String text, String... topicKeywords) {
        int topicIndex = firstTopicIndex(text, topicKeywords);
        if (topicIndex < 0) {
            return null;
        }
        Matcher matcher = TIME.matcher(text);
        String bestTime = null;
        Integer bestDistance = null;
        while (matcher.find()) {
            int distance = matcher.end() <= topicIndex
                    ? topicIndex - matcher.end()
                    : matcher.start() - topicIndex;
            if (bestDistance == null || distance < bestDistance) {
                bestDistance = distance;
                bestTime = formatMatchedTime(text, matcher);
            }
        }
        return bestTime;
    }

    private String resolveNearestTimeHint(String text, String... topicKeywords) {
        int topicIndex = firstTopicIndex(text, topicKeywords);
        if (topicIndex < 0) {
            return null;
        }
        List<String[]> hints = List.of(
                new String[]{"晚饭后", "19:00"},
                new String[]{"餐后", "19:00"},
                new String[]{"早上", "08:00"},
                new String[]{"上午", "08:00"},
                new String[]{"中午", "12:00"},
                new String[]{"下午", "15:00"},
                new String[]{"晚上", "20:00"},
                new String[]{"夜间", "20:00"}
        );
        String bestTime = null;
        Integer bestDistance = null;
        for (String[] hint : hints) {
            int start = text.indexOf(hint[0]);
            while (start >= 0) {
                int end = start + hint[0].length();
                int distance = end <= topicIndex ? topicIndex - end : start - topicIndex;
                if (bestDistance == null || distance < bestDistance) {
                    bestDistance = distance;
                    bestTime = hint[1];
                }
                start = text.indexOf(hint[0], end);
            }
        }
        return bestTime;
    }

    private int firstTopicIndex(String text, String... topicKeywords) {
        int best = -1;
        for (String keyword : topicKeywords) {
            int idx = text.indexOf(keyword);
            if (idx >= 0 && (best < 0 || idx < best)) {
                best = idx;
            }
        }
        return best;
    }

    private int countTimeHints(String text) {
        int count = 0;
        Matcher matcher = TIME.matcher(text);
        while (matcher.find()) {
            count++;
        }
        for (String keyword : List.of("早上", "上午", "中午", "下午", "晚上", "夜间", "晚饭后", "餐后")) {
            if (text.contains(keyword)) {
                count++;
            }
        }
        return count;
    }

    private Integer resolveDayOfWeek(String text) {
        Matcher matcher = WEEKDAY.matcher(text);
        if (!matcher.find()) {
            return null;
        }
        return switch (matcher.group(1)) {
            case "一", "1" -> DayOfWeek.MONDAY.getValue();
            case "二", "2" -> DayOfWeek.TUESDAY.getValue();
            case "三", "3" -> DayOfWeek.WEDNESDAY.getValue();
            case "四", "4" -> DayOfWeek.THURSDAY.getValue();
            case "五", "5" -> DayOfWeek.FRIDAY.getValue();
            case "六", "6" -> DayOfWeek.SATURDAY.getValue();
            case "日", "天", "7" -> DayOfWeek.SUNDAY.getValue();
            default -> null;
        };
    }

    private String resolveTimeText(String text) {
        Matcher matcher = TIME.matcher(text);
        if (matcher.find()) {
            return formatMatchedTime(text, matcher);
        }
        if (containsAny(text, "早上", "上午")) {
            return "08:00";
        }
        if (text.contains("中午")) {
            return "12:00";
        }
        if (text.contains("下午")) {
            return "15:00";
        }
        if (text.contains("晚饭后")) {
            return "19:00";
        }
        if (containsAny(text, "晚上", "夜间")) {
            return "20:00";
        }
        return null;
    }

    private String formatMatchedTime(String text, Matcher matcher) {
        int hour = Integer.parseInt(matcher.group(1));
        String minute = matcher.group(2) == null ? "00" : matcher.group(2);
        String timePrefix = text.substring(Math.max(0, matcher.start() - 6), matcher.start());
        if (containsAny(timePrefix, "下午", "晚上", "夜间", "晚饭后") && hour < 12) {
            hour += 12;
        }
        return String.format("%02d:%s", hour, minute);
    }

    private Map<String, Object> withCoordinates(String text, Map<String, Object> payload) {
        Matcher matcher = COORDINATES.matcher(text);
        if (matcher.find()) {
            payload.put("latitude", new BigDecimal(matcher.group(1)));
            payload.put("longitude", new BigDecimal(matcher.group(2)));
        }
        return payload;
    }

    private LocalDateTime recordedAt(String text) {
        LocalDateTime now = LocalDateTime.now();
        if (text.contains("昨天")) {
            return now.minusDays(1);
        }
        if (text.contains("前天")) {
            return now.minusDays(2);
        }
        return now;
    }

    private boolean hasRecordVerb(String text) {
        return containsAny(text, "帮我记录", "记一下", "记录一下", "录入", "保存", "登记");
    }

    private boolean hasMetricWithNumber(String text) {
        return parseBloodPressure(text) != null
                || HEART_RATE.matcher(text).find()
                || BLOOD_GLUCOSE.matcher(text).find()
                || WEIGHT.matcher(text).find();
    }

    private boolean containsAny(String text, String... keywords) {
        for (String keyword : keywords) {
            if (text.contains(keyword)) {
                return true;
            }
        }
        return false;
    }

    private String nowText() {
        return LocalDateTime.now().format(DATE_TIME_FORMATTER);
    }
}

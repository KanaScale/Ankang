package com.ankang.assistant.agent.action;

import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class AgentIntentParserTest {

    private final AgentIntentParser parser = new AgentIntentParser();

    @Test
    void recognizesHealthDataRecordIntent() {
        AgentActionRequest request = parser.parse("我今天早上血压 160/100，心率 108，帮我记一下").orElseThrow();

        assertThat(request.actionType()).isEqualTo(AgentActionType.RECORD_HEALTH_DATA);
        assertThat(request.requiresConfirmation()).isTrue();
        assertThat(request.payload()).containsEntry("systolic", 160).containsEntry("diastolic", 100);
        assertThat(request.payload()).containsEntry("heartRate", 108);
    }

    @Test
    void recognizesChineseBloodPressureFormat() {
        AgentActionRequest request = parser.parse("帮我记录一下，高压160，低压100").orElseThrow();

        assertThat(request.actionType()).isEqualTo(AgentActionType.RECORD_HEALTH_DATA);
        assertThat(request.payload()).containsEntry("systolic", 160).containsEntry("diastolic", 100);
    }

    @Test
    void recognizesHealthPlanIntent() {
        AgentActionRequest request = parser.parse("帮我每天早上 8 点测血压，晚上吃药").orElseThrow();

        assertThat(request.actionType()).isEqualTo(AgentActionType.CREATE_HEALTH_PLAN);
        assertThat(request.requiresConfirmation()).isTrue();
        assertThat(request.payload().get("reminders").toString()).contains("测血压", "服药提醒");
    }

    @Test
    void medicationStatusQuestionIsNotCreateReminderIntent() {
        assertThat(parser.parse("今天有没有按时吃药？")).isEmpty();
        assertThat(parser.parse("他今天有没有按时服药？")).isEmpty();
    }

    @Test
    void keepsSeparateTimesForMultiplePlanItems() {
        AgentActionRequest request = parser.parse("帮我每天早上 8 点测血压，晚上 9 点吃药").orElseThrow();

        assertThat(request.actionType()).isEqualTo(AgentActionType.CREATE_HEALTH_PLAN);
        assertThat(request.payload().get("reminders").toString())
                .contains("remindTime=08:00")
                .contains("remindTime=21:00");
    }

    @Test
    void keepsNearestTimesWithoutPunctuationBetweenPlanItems() {
        AgentActionRequest request = parser.parse("帮我每天早上8点测血压晚上9点吃药").orElseThrow();

        assertThat(request.payload().get("reminders").toString())
                .contains("remindTime=08:00")
                .contains("remindTime=21:00");
    }

    @Test
    void recognizesRiskAssessmentIntent() {
        AgentActionRequest request = parser.parse("我最近血糖异常，危险吗？").orElseThrow();

        assertThat(request.actionType()).isEqualTo(AgentActionType.EVALUATE_HEALTH_RISK);
        assertThat(request.requiresConfirmation()).isFalse();
    }

    @Test
    void recognizesSosPlanIntent() {
        AgentActionRequest request = parser.parse("我现在有点不舒服，帮我准备 SOS").orElseThrow();

        assertThat(request.actionType()).isEqualTo(AgentActionType.PREPARE_SOS_PLAN);
        assertThat(request.requiresConfirmation()).isTrue();
    }

    @Test
    void coversEmptyUnknownAndAllRemainingTopLevelIntents() {
        assertThat(parser.parse(null)).isEmpty();
        assertThat(parser.parse("   ")).isEmpty();
        assertThat(parser.parse("今天天气不错")).isEmpty();

        AgentActionRequest family = parser.parse("请通知家属我晚点回家").orElseThrow();
        assertThat(family.actionType()).isEqualTo(AgentActionType.NOTIFY_FAMILY_PREVIEW);

        AgentActionRequest hospital = parser.parse(
                "查询附近医院，纬度 31.2304，经度 121.4737"
        ).orElseThrow();
        assertThat(hospital.actionType()).isEqualTo(AgentActionType.SEARCH_NEARBY_HOSPITALS);
        assertThat(hospital.payload()).containsKeys("latitude", "longitude", "radiusMeters");

        AgentActionRequest sos = parser.parse(
                "胸痛，请准备急救方案，纬度 -31.2，经度 -121.5"
        ).orElseThrow();
        assertThat(sos.payload()).containsKeys("latitude", "longitude");
    }

    @Test
    void parsesEverySupportedHealthMetricAndRelativeDate() {
        AgentActionRequest metrics = parser.parse(
                "帮我记录昨天餐后血糖 8.50，心率 105，体重 65.20"
        ).orElseThrow();
        assertThat(metrics.payload())
                .containsKeys("bloodGlucose", "heartRate", "weight", "recordedAt")
                .containsEntry("glucosePeriod", "post_meal");

        AgentActionRequest fasting = parser.parse("空腹血糖 5.6").orElseThrow();
        assertThat(fasting.payload()).containsEntry("glucosePeriod", "fasting");
        AgentActionRequest unknown = parser.parse("血糖 6.1").orElseThrow();
        assertThat(unknown.payload()).containsEntry("glucosePeriod", "unknown");
        assertThat(parser.parse("帮我记录一下但没有数值")).isEmpty();
    }

    @Test
    void parsesAlternativeBloodPressureFormats() {
        for (String text : List.of(
                "记录高压 150，低压 95",
                "记录低压 90，高压 145",
                "记录血压 140 到 88"
        )) {
            AgentActionRequest request = parser.parse(text).orElseThrow();
            assertThat(request.actionType()).isEqualTo(AgentActionType.RECORD_HEALTH_DATA);
            assertThat(request.payload()).containsKeys("systolic", "diastolic");
        }
    }

    @Test
    void planParsingCoversWeeklyHintsMissingTimeAndAllTopics() {
        AgentActionRequest noTime = parser.parse("制定测血压和运动计划").orElseThrow();
        assertThat(noTime.payload().get("reminders").toString()).isEqualTo("[]");

        for (String day : List.of("一", "二", "三", "四", "五", "六", "日", "天", "7")) {
            AgentActionRequest weekly = parser.parse(
                    "每周" + day + "上午 9 点测血糖"
            ).orElseThrow();
            assertThat(weekly.payload().get("reminders").toString())
                    .contains("repeatType=weekly", "dayOfWeek=");
        }

        AgentActionRequest topics = parser.parse(
                "每天早上测血压，中午测血糖，下午运动，晚饭后服药"
        ).orElseThrow();
        assertThat(topics.payload().get("reminders").toString())
                .contains("bloodPressure", "bloodSugar", "other", "medicine");

        AgentActionRequest explicitMinutes = parser.parse(
                "每天上午 08:35 服药，晚上 21:45 运动"
        ).orElseThrow();
        assertThat(explicitMinutes.payload().get("reminders").toString())
                .contains("08:35", "21:45");
    }

    @Test
    void helperBranchesCoverMissingAndLaterTopicsPunctuationAndCoordinates() {
        @SuppressWarnings("unchecked")
        List<String> segments = ReflectionTestUtils.invokeMethod(
                parser, "splitPlanSegments", "第一项； ；第二项。第三项"
        );
        assertThat(segments).containsExactly("第一项", "第二项", "第三项");

        assertThat((Integer) ReflectionTestUtils.invokeMethod(
                parser, "firstTopicIndex", "先运动再服药",
                new String[]{"不存在", "服药"})).isPositive();
        assertThat((Integer) ReflectionTestUtils.invokeMethod(
                parser, "firstTopicIndex", "无主题",
                new String[]{"服药"})).isEqualTo(-1);

        @SuppressWarnings("unchecked")
        Map<String, Object> withoutCoordinates = ReflectionTestUtils.invokeMethod(
                parser, "withCoordinates", "没有坐标", new java.util.LinkedHashMap<>()
        );
        assertThat(withoutCoordinates).isEmpty();
        @SuppressWarnings("unchecked")
        Map<String, Object> withCoordinates = ReflectionTestUtils.invokeMethod(
                parser, "withCoordinates", "纬度31.2，经度121.5", new java.util.LinkedHashMap<>()
        );
        assertThat(withCoordinates).containsKeys("latitude", "longitude");
    }

    @Test
    void allNamedTimeHintsAndRelativeDateBranchesAreCovered() {
        for (Map.Entry<String, String> hint : Map.of(
                "早上", "08:00",
                "上午", "08:00",
                "中午", "12:00",
                "下午", "15:00",
                "晚饭后", "19:00",
                "晚上", "20:00",
                "夜间", "20:00"
        ).entrySet()) {
            assertThat((String) ReflectionTestUtils.invokeMethod(
                    parser, "resolveTimeText", hint.getKey())).isEqualTo(hint.getValue());
        }
        assertThat((String) ReflectionTestUtils.invokeMethod(
                parser, "resolveTimeText", "下午11点")).isEqualTo("23:00");
        assertThat((String) ReflectionTestUtils.invokeMethod(
                parser, "resolveTimeText", "上午11点")).isEqualTo("11:00");

        LocalDateTime yesterday = ReflectionTestUtils.invokeMethod(parser, "recordedAt", "昨天");
        LocalDateTime dayBefore = ReflectionTestUtils.invokeMethod(parser, "recordedAt", "前天");
        LocalDateTime today = ReflectionTestUtils.invokeMethod(parser, "recordedAt", "今天");
        assertThat(yesterday).isBefore(today);
        assertThat(dayBefore).isBefore(yesterday);
    }

    @Test
    void nearestTimeSelectionCoversBeforeAfterAndAmbiguousGeneralTime() {
        assertThat((String) ReflectionTestUtils.invokeMethod(
                parser, "resolveNearestNumericTime",
                "早上8点运动，晚上9点服药", new String[]{"服药"}))
                .isEqualTo("21:00");
        assertThat((String) ReflectionTestUtils.invokeMethod(
                parser, "resolveNearestTimeHint",
                "早上运动，晚上服药", new String[]{"服药"}))
                .isEqualTo("20:00");
        assertThat((String) ReflectionTestUtils.invokeMethod(
                parser, "resolveTopicTime",
                "早上8点运动，晚上9点服药", "08:00", new String[]{"测血压"}))
                .isNull();
    }
}

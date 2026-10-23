package com.ankang.assistant.eventmesh.service;

import com.ankang.assistant.eventmesh.vo.RiskAssessment;
import com.ankang.assistant.health.entity.HealthRecord;
import com.ankang.assistant.health.mapper.HealthRecordMapper;
import com.ankang.assistant.reminder.entity.Reminder;
import com.ankang.assistant.reminder.mapper.ReminderMapper;
import com.baomidou.mybatisplus.core.conditions.Wrapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class RiskEngineServiceTest {

    @Mock
    private HealthRecordMapper healthRecordMapper;
    @Mock
    private ReminderMapper reminderMapper;

    @Test
    void combinesLatestMetricsAndMedicationReminderIntoHighRiskAssessment() {
        when(healthRecordMapper.selectList(any(Wrapper.class))).thenReturn(List.of(
                pressure(168, 108), metric("heart_rate", "116"), metric("blood_glucose", "11.2")
        ));
        Reminder medication = new Reminder();
        medication.setType("medicine");
        medication.setEnabled(true);
        medication.setRepeatType("daily");
        when(reminderMapper.selectList(any(Wrapper.class))).thenReturn(List.of(medication));

        RiskAssessment result = engine().assess(7L);

        assertThat(result.level()).isEqualTo("high");
        assertThat(result.score()).isEqualTo(100);
        assertThat(result.reasons()).anyMatch(reason -> reason.contains("血压明显偏高"));
        assertThat(result.reasons()).anyMatch(reason -> reason.contains("心率"));
        assertThat(result.reasons()).anyMatch(reason -> reason.contains("血糖明显偏高"));
        assertThat(result.reasons()).contains("今日服药提醒尚未完成");
    }

    @Test
    void highlightsTheActualInputAndLabelsRelatedRecentMetrics() {
        HealthRecord current = metric("heart_rate", "116");
        current.setId(99L);
        current.setUserId(7L);
        HealthRecord recentGlucose = metric("blood_glucose", "11.2");
        when(healthRecordMapper.selectById(99L)).thenReturn(current);
        when(healthRecordMapper.selectList(any(Wrapper.class))).thenReturn(List.of(
                recentGlucose, current
        ));
        when(reminderMapper.selectList(any(Wrapper.class))).thenReturn(List.of());

        RiskAssessment result = engine().assess(7L, 99L);

        assertThat(result.level()).isEqualTo("elevated");
        assertThat(result.score()).isEqualTo(55);
        assertThat(result.summary()).contains("本次录入心率 116 bpm").contains("55 分");
        assertThat(result.reasons()).contains("本次录入：心率处于偏快或偏慢状态（116 bpm）");
        assertThat(result.reasons()).contains("近 24 小时关联数据：血糖明显偏高（11.2 mmol/L）");
    }

    @Test
    void abnormalCurrentInputTriggersAlertWithItsOwnReading() {
        HealthRecord current = pressure(145, 88);
        current.setId(100L);
        current.setUserId(7L);
        when(healthRecordMapper.selectById(100L)).thenReturn(current);
        when(healthRecordMapper.selectList(any(Wrapper.class))).thenReturn(List.of(current));
        when(reminderMapper.selectList(any(Wrapper.class))).thenReturn(List.of());

        RiskAssessment result = engine().assess(7L, 100L);

        assertThat(result.level()).isEqualTo("elevated");
        assertThat(result.score()).isEqualTo(25);
        assertThat(result.summary()).contains("本次录入血压 145/88 mmHg");
        assertThat(result.reasons()).containsExactly("本次录入：血压高于建议范围（145/88 mmHg）");
    }

    @Test
    void normalCurrentInputDoesNotProduceAFixedWarning() {
        HealthRecord current = pressure(128, 82);
        current.setId(101L);
        current.setUserId(7L);
        when(healthRecordMapper.selectById(101L)).thenReturn(current);
        when(healthRecordMapper.selectList(any(Wrapper.class))).thenReturn(List.of(current));
        when(reminderMapper.selectList(any(Wrapper.class))).thenReturn(List.of());

        RiskAssessment result = engine().assess(7L, 101L);

        assertThat(result.level()).isEqualTo("normal");
        assertThat(result.score()).isZero();
        assertThat(result.summary())
                .contains("本次录入血压 128/82 mmHg")
                .contains("未触发医学规则或个体异常模型");
    }

    @Test
    void withinRangeReadingTriggersAlertWhenItDeviatesFromPersonalBaseline() {
        LocalDateTime now = LocalDateTime.now().withHour(9);
        List<HealthRecord> records = new ArrayList<>();
        for (int day = 14; day >= 1; day--) {
            HealthRecord historical = metric("heart_rate", Integer.toString(68 + day % 5));
            historical.setId((long) day);
            historical.setUserId(7L);
            historical.setSource("smart_band");
            historical.setRecordedAt(now.minusDays(day));
            records.add(historical);
        }
        HealthRecord current = metric("heart_rate", "96");
        current.setId(102L);
        current.setUserId(7L);
        current.setSource("smart_band");
        current.setRecordedAt(now);
        records.add(current);
        when(healthRecordMapper.selectById(102L)).thenReturn(current);
        when(healthRecordMapper.selectList(any(Wrapper.class))).thenReturn(records);
        when(reminderMapper.selectList(any(Wrapper.class))).thenReturn(List.of());

        RiskAssessment result = engine().assess(7L, 102L);

        assertThat(result.level()).isEqualTo("elevated");
        assertThat(result.score()).isPositive();
        assertThat(result.reasons())
                .anyMatch(reason -> reason.contains("个体基线")
                        && reason.contains("心率")
                        && reason.contains("MAD"));
        assertThat(result.summary()).contains("本次录入心率 96 bpm");
    }

    @Test
    void coversCriticalLowAndMetabolicMedicalThresholds() {
        when(reminderMapper.selectList(any(Wrapper.class))).thenReturn(List.of());

        HealthRecord criticalPressure = pressure(185, 121);
        criticalPressure.setId(201L);
        criticalPressure.setUserId(7L);
        when(healthRecordMapper.selectById(201L)).thenReturn(criticalPressure);
        when(healthRecordMapper.selectList(any(Wrapper.class))).thenReturn(List.of(criticalPressure));
        RiskAssessment critical = engine().assess(7L, 201L);
        assertThat(critical.level()).isEqualTo("high");
        assertThat(critical.score()).isEqualTo(60);

        HealthRecord lowPressure = pressure(85, 55);
        lowPressure.setId(202L);
        lowPressure.setUserId(7L);
        when(healthRecordMapper.selectById(202L)).thenReturn(lowPressure);
        when(healthRecordMapper.selectList(any(Wrapper.class))).thenReturn(List.of(lowPressure));
        assertThat(engine().assess(7L, 202L).score()).isEqualTo(25);

        HealthRecord extremeHeartRate = metric("heart_rate", "130");
        extremeHeartRate.setId(203L);
        extremeHeartRate.setUserId(7L);
        when(healthRecordMapper.selectById(203L)).thenReturn(extremeHeartRate);
        when(healthRecordMapper.selectList(any(Wrapper.class))).thenReturn(List.of(extremeHeartRate));
        assertThat(engine().assess(7L, 203L).score()).isEqualTo(40);

        HealthRecord moderatelyHighGlucose = metric("blood_glucose", "7.0");
        moderatelyHighGlucose.setId(204L);
        moderatelyHighGlucose.setUserId(7L);
        when(healthRecordMapper.selectById(204L)).thenReturn(moderatelyHighGlucose);
        when(healthRecordMapper.selectList(any(Wrapper.class))).thenReturn(List.of(moderatelyHighGlucose));
        assertThat(engine().assess(7L, 204L).score()).isEqualTo(20);

        HealthRecord lowGlucose = metric("blood_glucose", "3.5");
        lowGlucose.setId(205L);
        lowGlucose.setUserId(7L);
        when(healthRecordMapper.selectById(205L)).thenReturn(lowGlucose);
        when(healthRecordMapper.selectList(any(Wrapper.class))).thenReturn(List.of(lowGlucose));
        assertThat(engine().assess(7L, 205L).score()).isEqualTo(20);
    }

    @Test
    void coversRightHandThresholdAlternativesAndIncompletePressure() {
        when(reminderMapper.selectList(any(Wrapper.class))).thenReturn(List.of());

        List<HealthRecord> cases = List.of(
                pressure(130, 120),
                pressure(130, 100),
                pressure(130, 90),
                pressure(100, 55),
                metric("heart_rate", "45"),
                metric("heart_rate", "55")
        );
        int[] expectedScores = {60, 45, 25, 25, 40, 25};
        for (int index = 0; index < cases.size(); index++) {
            HealthRecord current = cases.get(index);
            long id = 300L + index;
            current.setId(id);
            current.setUserId(7L);
            when(healthRecordMapper.selectById(id)).thenReturn(current);
            when(healthRecordMapper.selectList(any(Wrapper.class))).thenReturn(List.of(current));
            assertThat(engine().assess(7L, id).score()).isEqualTo(expectedScores[index]);
        }

        HealthRecord missingSystolic = pressure(120, 80);
        missingSystolic.setId(310L);
        missingSystolic.setUserId(7L);
        missingSystolic.setSystolic(null);
        when(healthRecordMapper.selectById(310L)).thenReturn(missingSystolic);
        when(healthRecordMapper.selectList(any(Wrapper.class))).thenReturn(List.of(missingSystolic));
        assertThat(engine().assess(7L, 310L).score()).isZero();

        HealthRecord missingDiastolic = pressure(120, 80);
        missingDiastolic.setId(311L);
        missingDiastolic.setUserId(7L);
        missingDiastolic.setDiastolic(null);
        when(healthRecordMapper.selectById(311L)).thenReturn(missingDiastolic);
        when(healthRecordMapper.selectList(any(Wrapper.class))).thenReturn(List.of(missingDiastolic));
        assertThat(engine().assess(7L, 311L).score()).isZero();
    }

    @Test
    void coversNoCurrentSummaryVariantsAndSafeUnknownReadings() {
        when(reminderMapper.selectList(any(Wrapper.class))).thenReturn(List.of());

        HealthRecord relatedHeartRate = metric("heart_rate", "130");
        when(healthRecordMapper.selectList(any(Wrapper.class))).thenReturn(List.of(relatedHeartRate));
        RiskAssessment elevatedWithoutCurrent = engine().assess(7L, 999L);
        assertThat(elevatedWithoutCurrent.level()).isEqualTo("elevated");

        HealthRecord unknown = new HealthRecord();
        unknown.setId(206L);
        unknown.setUserId(7L);
        unknown.setType("temperature");
        unknown.setRecordedAt(LocalDateTime.now());
        when(healthRecordMapper.selectById(206L)).thenReturn(unknown);
        when(healthRecordMapper.selectList(any(Wrapper.class))).thenReturn(List.of(unknown));
        RiskAssessment safeUnknown = engine().assess(7L, 206L);
        assertThat(safeUnknown.level()).isEqualTo("normal");
        assertThat(safeUnknown.summary()).contains("--");

        HealthRecord otherUsersRecord = metric("heart_rate", "72");
        otherUsersRecord.setUserId(8L);
        when(healthRecordMapper.selectById(207L)).thenReturn(otherUsersRecord);
        when(healthRecordMapper.selectList(any(Wrapper.class))).thenReturn(List.of());
        RiskAssessment empty = engine().assess(7L, 207L);
        assertThat(empty.level()).isEqualTo("normal");
        assertThat(empty.score()).isZero();
    }

    @Test
    void completedOrFutureMedicationRemindersDoNotIncreaseRisk() {
        when(healthRecordMapper.selectList(any(Wrapper.class))).thenReturn(List.of());

        Reminder noType = new Reminder();
        Reminder completedOnce = new Reminder();
        completedOnce.setType("medicine");
        completedOnce.setRepeatType("once");
        completedOnce.setCompleted(true);
        Reminder futureOnce = new Reminder();
        futureOnce.setType("medicine");
        futureOnce.setRepeatType("once");
        futureOnce.setCompleted(false);
        futureOnce.setRemindAt(LocalDateTime.now().plusDays(1));
        Reminder completedDaily = new Reminder();
        completedDaily.setType("medication");
        completedDaily.setRepeatType("daily");
        completedDaily.setLastCompletedDate(LocalDate.now());
        when(reminderMapper.selectList(any(Wrapper.class)))
                .thenReturn(List.of(noType, completedOnce, futureOnce, completedDaily));

        RiskAssessment result = engine().assess(7L);

        assertThat(result.score()).isZero();
        assertThat(result.level()).isEqualTo("normal");
    }

    @Test
    void stateMachineRejectsSkippingAssessmentStages() {
        assertThat(EventProcessingState.RECEIVED.canTransitionTo(EventProcessingState.PUBLISHED)).isTrue();
        assertThat(EventProcessingState.RECEIVED.canTransitionTo(EventProcessingState.ALERTED)).isFalse();
        assertThat(EventProcessingState.ALERTED.canTransitionTo(EventProcessingState.PUSHED)).isTrue();
    }

    private HealthRecord pressure(int systolic, int diastolic) {
        HealthRecord record = metric("blood_pressure", Integer.toString(systolic));
        record.setSystolic(systolic);
        record.setDiastolic(diastolic);
        return record;
    }

    private HealthRecord metric(String type, String value) {
        HealthRecord record = new HealthRecord();
        record.setType(type);
        record.setValue(new BigDecimal(value));
        record.setRecordedAt(LocalDateTime.now());
        return record;
    }

    private RiskEngineService engine() {
        return new RiskEngineService(
                healthRecordMapper,
                reminderMapper,
                new AdaptiveRiskAnalyzer()
        );
    }
}

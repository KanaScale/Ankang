package com.ankang.assistant.medicalsummary.service;

import com.ankang.assistant.config.JwtService;
import com.ankang.assistant.eventmesh.entity.HealthEvent;
import com.ankang.assistant.eventmesh.mapper.HealthEventMapper;
import com.ankang.assistant.health.entity.HealthRecord;
import com.ankang.assistant.health.mapper.HealthRecordMapper;
import com.ankang.assistant.medicalsummary.vo.MedicalSummaryVO;
import com.ankang.assistant.reminder.entity.Reminder;
import com.ankang.assistant.reminder.mapper.ReminderMapper;
import com.ankang.assistant.user.service.UserService;
import com.ankang.assistant.user.vo.HealthProfileVO;
import com.ankang.assistant.user.vo.UserProfileVO;
import com.baomidou.mybatisplus.core.conditions.Wrapper;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class MedicalSummaryServiceTest {

    @Mock
    private UserService userService;
    @Mock
    private HealthRecordMapper healthRecordMapper;
    @Mock
    private ReminderMapper reminderMapper;
    @Mock
    private HealthEventMapper healthEventMapper;

    @AfterEach
    void clearSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void buildsObjectiveInAppSummaryWithoutRecordRemarks() {
        authenticateAs(42L);
        when(userService.getProfileByUserId(42L)).thenReturn(new UserProfileVO(
                42L, "sophia", "Sophia", 62, "female", null, null, null, "user"
        ));
        when(userService.getHealthProfileByUserId(42L)).thenReturn(new HealthProfileVO(
                new BigDecimal("165"), new BigDecimal("60"), new BigDecimal("22.04"),
                List.of("高血压"), "青霉素", "2022 年体检提示血压偏高", "智能手环"
        ));

        HealthRecord pressure = pressure(145, 92, "warning");
        pressure.setRemark("这段用户自述不应出现在摘要");
        HealthRecord heartRate = metric("heart_rate", "72", "normal", "smart_band");
        when(healthRecordMapper.selectList(any(Wrapper.class))).thenReturn(List.of(pressure, heartRate));

        Reminder medicine = new Reminder();
        medicine.setTitle("降压药");
        medicine.setType("medicine");
        medicine.setEnabled(true);
        medicine.setRepeatType("daily");
        medicine.setRemindAt(LocalDateTime.now().withHour(8));
        medicine.setLastCompletedDate(LocalDate.now());
        when(reminderMapper.selectList(any(Wrapper.class))).thenReturn(List.of(medicine));

        HealthEvent riskEvent = new HealthEvent();
        riskEvent.setEventId("evt-1");
        riskEvent.setRiskLevel("elevated");
        riskEvent.setRiskScore(38);
        riskEvent.setSummary("本次血压高于建议范围");
        riskEvent.setReasonsJson("[\"收缩压高于建议范围\"]");
        riskEvent.setOccurredAt(LocalDateTime.now());
        when(healthEventMapper.selectList(any(Wrapper.class))).thenReturn(List.of(riskEvent));

        MedicalSummaryVO summary = service().generate(14);

        assertThat(summary.patient().displayName()).isEqualTo("Sophia");
        assertThat(summary.rangeDays()).isEqualTo(14);
        assertThat(summary.totalRecordCount()).isEqualTo(2);
        assertThat(summary.abnormalRecordCount()).isEqualTo(1);
        assertThat(summary.metrics()).extracting(MedicalSummaryVO.MetricSummaryVO::label)
                .containsExactly("血压", "心率");
        assertThat(summary.metrics().get(0).latestValue()).isEqualTo("145/92");
        assertThat(summary.medication().completedCurrentCycleCount()).isEqualTo(1);
        assertThat(summary.riskEvents().get(0).reasons()).containsExactly("收缩压高于建议范围");
        assertThat(summary.toString()).doesNotContain("这段用户自述");
        assertThat(summary.disclaimer()).contains("不代表医生诊断");
    }

    @Test
    void coversFallbackNamesSourcesMetricsMalformedReasonsAndMedicationCycles() {
        authenticateAs(42L);
        when(userService.getProfileByUserId(42L)).thenReturn(new UserProfileVO(
                42L, " fallback-user ", " ", 62, "female", null, null, null, "user"
        ));
        when(userService.getHealthProfileByUserId(42L)).thenReturn(new HealthProfileVO(
                new BigDecimal("165"), new BigDecimal("60"), new BigDecimal("22.04"),
                null, null, null, null
        ));

        HealthRecord glucose = metric("blood_glucose", "6.5", "warning", "band");
        glucose.setUnit("mmol/L");
        HealthRecord weight = metric("weight", "60.5", "normal", "device");
        weight.setUnit("kg");
        HealthRecord steps = metric("steps", "8560", "normal", null);
        steps.setUnit("steps");
        HealthRecord sleep = metric("sleep_hours", "7.5", "normal", "wearable");
        sleep.setUnit("hour");
        HealthRecord other = metric("other", "3.25", "normal", "custom");
        other.setValue1(other.getValue());
        other.setValue(null);
        other.setUnit("score");
        when(healthRecordMapper.selectList(any(Wrapper.class)))
                .thenReturn(List.of(glucose, weight, steps, sleep, other));

        Reminder once = new Reminder();
        once.setTitle("once");
        once.setRepeatType("once");
        once.setCompleted(true);
        Reminder weekly = new Reminder();
        weekly.setTitle("weekly");
        weekly.setRepeatType("weekly");
        weekly.setLastCompletedDate(LocalDate.now());
        Reminder dailyIncomplete = new Reminder();
        dailyIncomplete.setTitle("daily");
        dailyIncomplete.setRepeatType("daily");
        when(reminderMapper.selectList(any(Wrapper.class)))
                .thenReturn(List.of(once, weekly, dailyIncomplete));

        HealthEvent malformed = new HealthEvent();
        malformed.setEventId("evt-malformed");
        malformed.setRiskLevel("elevated");
        malformed.setRiskScore(35);
        malformed.setSummary("summary");
        malformed.setReasonsJson("{not-json");
        malformed.setOccurredAt(LocalDateTime.now());
        HealthEvent blankReasons = new HealthEvent();
        blankReasons.setEventId("evt-blank");
        blankReasons.setRiskLevel("elevated");
        blankReasons.setRiskScore(35);
        blankReasons.setSummary("summary");
        blankReasons.setReasonsJson(" ");
        blankReasons.setOccurredAt(LocalDateTime.now().minusMinutes(1));
        when(healthEventMapper.selectList(any(Wrapper.class)))
                .thenReturn(List.of(malformed, blankReasons));

        MedicalSummaryVO summary = service().generate(null);

        assertThat(summary.rangeDays()).isEqualTo(14);
        assertThat(summary.patient().displayName()).isEqualTo("fallback-user");
        assertThat(summary.healthProfile().chronicDiseases()).isEmpty();
        assertThat(summary.metrics())
                .extracting(MedicalSummaryVO.MetricSummaryVO::type)
                .containsExactly("blood_glucose", "weight", "steps", "sleep_hours", "other");
        assertThat(summary.metrics().get(4).latestValue()).isEqualTo("3.25");
        assertThat(summary.riskEvents().get(0).reasons()).isEmpty();
        assertThat(summary.riskEvents().get(1).reasons()).isEmpty();
        assertThat(summary.medication().completedCurrentCycleCount()).isEqualTo(2);
        assertThat(summary.dataSources())
                .extracting(MedicalSummaryVO.DataSourceVO::source)
                .containsExactly("band", "device", "unknown", "wearable", "custom");
    }

    @Test
    void usesPlaceholderNameAndHandlesIncompletePressureValues() {
        authenticateAs(42L);
        when(userService.getProfileByUserId(42L)).thenReturn(new UserProfileVO(
                42L, " ", null, 62, "female", null, null, null, "user"
        ));
        when(userService.getHealthProfileByUserId(42L)).thenReturn(new HealthProfileVO(
                null, null, null, List.of(), null, null, null
        ));
        HealthRecord incompletePressure = pressure(145, 92, "warning");
        incompletePressure.setSystolic(null);
        incompletePressure.setValue1(new BigDecimal("145"));
        when(healthRecordMapper.selectList(any(Wrapper.class))).thenReturn(List.of(incompletePressure));
        when(reminderMapper.selectList(any(Wrapper.class))).thenReturn(List.of());
        when(healthEventMapper.selectList(any(Wrapper.class))).thenReturn(List.of());

        MedicalSummaryVO summary = service().generate(7);

        assertThat(summary.patient().displayName()).isNotBlank();
        assertThat(summary.metrics()).singleElement().satisfies(metric -> {
            assertThat(metric.averageValue()).isNull();
            assertThat(metric.latestValue()).isEqualTo("145");
        });
    }

    @Test
    void rejectsUnsupportedRange() {
        assertThatThrownBy(() -> service().generate(3))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("7 到 90 天");
        assertThatThrownBy(() -> service().generate(91))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("7 到 90 天");
    }

    private MedicalSummaryService service() {
        return new MedicalSummaryService(
                userService,
                healthRecordMapper,
                reminderMapper,
                healthEventMapper,
                new ObjectMapper()
        );
    }

    private HealthRecord pressure(int systolic, int diastolic, String status) {
        HealthRecord record = new HealthRecord();
        record.setUserId(42L);
        record.setType("blood_pressure");
        record.setSystolic(systolic);
        record.setDiastolic(diastolic);
        record.setUnit("mmHg");
        record.setStatus(status);
        record.setSource("manual");
        record.setRecordedAt(LocalDateTime.now().minusHours(1));
        return record;
    }

    private HealthRecord metric(String type, String value, String status, String source) {
        HealthRecord record = new HealthRecord();
        record.setUserId(42L);
        record.setType(type);
        record.setValue(new BigDecimal(value));
        record.setUnit("bpm");
        record.setStatus(status);
        record.setSource(source);
        record.setRecordedAt(LocalDateTime.now().minusHours(2));
        return record;
    }

    private void authenticateAs(Long userId) {
        JwtService.JwtUser principal = new JwtService.JwtUser(userId, "medical-summary-test");
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(principal, null, List.of())
        );
    }
}

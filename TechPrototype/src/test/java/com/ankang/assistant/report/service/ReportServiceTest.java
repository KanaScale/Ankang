package com.ankang.assistant.report.service;

import com.ankang.assistant.health.entity.HealthRecord;
import com.ankang.assistant.health.mapper.HealthRecordMapper;
import com.ankang.assistant.config.RedisCacheSupport;
import com.ankang.assistant.report.vo.WeeklyHealthReportVO;
import com.baomidou.mybatisplus.core.conditions.Wrapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ReportServiceTest {

    @Mock
    private HealthRecordMapper healthRecordMapper;

    @Test
    void buildsWeeklyReportFromHealthRecords() {
        when(healthRecordMapper.selectList(any(Wrapper.class))).thenReturn(List.of(
                record("heart_rate", "70", "normal"),
                record("heart_rate", "80", "warning")
        ));
        ReportService reportService = new ReportService(healthRecordMapper);

        WeeklyHealthReportVO report = reportService.weeklyReport(LocalDate.of(2026, 7, 6));

        assertThat(report.weekStart()).isEqualTo("2026-07-06");
        assertThat(report.weekEnd()).isEqualTo("2026-07-12");
        assertThat(report.indicators()).containsEntry("recordCount", 2);
        assertThat(report.indicators()).containsEntry("heartRateAvg", new BigDecimal("75"));
        assertThat(report.indicators()).containsEntry("abnormalCount", 1L);
        assertThat(report.summary()).contains("1 次指标需要关注");
    }

    @Test
    void coversCacheHitMissEmptyNormalAndEveryAverageType() {
        RedisCacheSupport cache = org.mockito.Mockito.mock(RedisCacheSupport.class);
        WeeklyHealthReportVO cached = new WeeklyHealthReportVO(
                "2026-01-05", "2026-01-11", "cached", java.util.Map.of()
        );
        when(cache.get(any(), any())).thenReturn(cached, null);
        ReportService service = new ReportService(healthRecordMapper, cache);
        assertThat(service.weeklyReport(LocalDate.of(2026, 1, 5))).isSameAs(cached);

        when(healthRecordMapper.selectList(any(Wrapper.class))).thenReturn(List.of());
        WeeklyHealthReportVO empty = service.weeklyReport(null);
        assertThat(empty.indicators()).containsEntry("recordCount", 0);
        org.mockito.Mockito.verify(cache).set(any(), any(), any());

        HealthRecord pressure = record("blood_pressure", "0", "normal");
        pressure.setSystolic(121);
        pressure.setDiastolic(81);
        HealthRecord glucose = record("blood_glucose", "5.5", "normal");
        HealthRecord weight = record("weight", "65", "normal");
        HealthRecord value1 = record("heart_rate", "70", "normal");
        value1.setValue(null);
        value1.setValue1(new BigDecimal("72"));
        when(healthRecordMapper.selectList(any(Wrapper.class)))
                .thenReturn(List.of(pressure, glucose, weight, value1));
        WeeklyHealthReportVO normal = new ReportService(healthRecordMapper)
                .weeklyReport(LocalDate.of(2026, 1, 5));
        assertThat(normal.indicators())
                .containsEntry("bloodPressureAvg", "121/81")
                .containsEntry("bloodGlucoseAvg", new BigDecimal("5.5"))
                .containsEntry("weightAvg", new BigDecimal("65"))
                .containsEntry("heartRateAvg", new BigDecimal("72"));
        assertThat(normal.summary()).isNotBlank();
    }

    @Test
    void ignoresIncompletePressureAndNullScalarValues() {
        HealthRecord nonPressure = record("heart_rate", "70", "normal");
        nonPressure.setSystolic(120);
        nonPressure.setDiastolic(80);

        HealthRecord pressureWithoutDiastolic = record("blood_pressure", "0", "normal");
        pressureWithoutDiastolic.setSystolic(125);
        pressureWithoutDiastolic.setDiastolic(null);

        HealthRecord nullScalar = record("weight", "0", "normal");
        nullScalar.setValue(null);
        nullScalar.setValue1(null);

        when(healthRecordMapper.selectList(any(Wrapper.class)))
                .thenReturn(List.of(nonPressure, pressureWithoutDiastolic, nullScalar));

        WeeklyHealthReportVO report = new ReportService(healthRecordMapper)
                .weeklyReport(LocalDate.of(2026, 1, 5));

        assertThat(report.indicators())
                .doesNotContainKeys("bloodPressureAvg", "weightAvg");
        assertThat((BigDecimal) report.indicators().get("heartRateAvg"))
                .isEqualByComparingTo("70");
    }

    private HealthRecord record(String type, String value, String status) {
        HealthRecord record = new HealthRecord();
        record.setUserId(1L);
        record.setType(type);
        record.setValue(new BigDecimal(value));
        record.setStatus(status);
        record.setRecordedAt(LocalDateTime.of(2026, 7, 7, 8, 0));
        return record;
    }
}

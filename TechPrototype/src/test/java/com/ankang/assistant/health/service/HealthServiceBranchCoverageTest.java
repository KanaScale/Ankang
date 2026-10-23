package com.ankang.assistant.health.service;

import com.ankang.assistant.health.entity.HealthRecord;
import com.ankang.assistant.health.mapper.HealthRecordMapper;
import com.baomidou.mybatisplus.core.MybatisConfiguration;
import com.baomidou.mybatisplus.core.metadata.TableInfoHelper;
import org.apache.ibatis.builder.MapperBuilderAssistant;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigDecimal;
import java.time.LocalDate;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;

class HealthServiceBranchCoverageTest {

    private HealthService service;

    @BeforeEach
    void setUp() {
        TableInfoHelper.initTableInfo(
                new MapperBuilderAssistant(new MybatisConfiguration(), ""), HealthRecord.class);
        service = new HealthService(mock(HealthRecordMapper.class));
    }

    @Test
    void coversValidationShortCircuitBoundaries() {
        assertThatThrownBy(() -> invoke("assertValidUserId", (Long) null)).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> invoke("assertValidUserId", -1L)).isInstanceOf(IllegalArgumentException.class);
        invoke("assertValidUserId", 1L);

        LocalDate today = LocalDate.now();
        invoke("validateDateRange", null, today);
        invoke("validateDateRange", today, null);
        invoke("validateDateRange", today, today);

        assertThatThrownBy(() -> invoke("validateBloodPressure", null, 80)).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> invoke("validateBloodPressure", 120, null)).isInstanceOf(IllegalArgumentException.class);
        for (int[] pair : new int[][]{{39, 30}, {301, 80}, {120, 29}, {220, 201}, {80, 80}}) {
            assertThatThrownBy(() -> invoke("validateBloodPressure", pair[0], pair[1]))
                    .isInstanceOf(IllegalArgumentException.class);
        }
        invoke("validateBloodPressure", 120, 80);

        assertThatThrownBy(() -> invoke("validateValue", "weight", null)).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> invoke("validateValue", "weight", BigDecimal.ZERO)).isInstanceOf(IllegalArgumentException.class);
        invoke("validateValue", "weight", BigDecimal.ONE);
    }

    @Test
    void coversStatusDecisionShortCircuitBranches() {
        assertStatus("danger", "blood_pressure", null, 160, 80);
        assertStatus("danger", "blood_pressure", null, 120, 100);
        assertStatus("warning", "blood_pressure", null, 140, 80);
        assertStatus("warning", "blood_pressure", null, 120, 90);
        assertStatus("warning", "blood_pressure", null, 89, 70);
        assertStatus("warning", "blood_pressure", null, 120, 59);
        assertStatus("normal", "blood_pressure", null, 120, 80);

        assertStatus("danger", "blood_glucose", "11.1", null, null);
        assertStatus("warning", "blood_glucose", "6.2", null, null);
        assertStatus("warning", "blood_glucose", "3.8", null, null);
        assertStatus("normal", "blood_glucose", "5", null, null);

        assertStatus("danger", "heart_rate", "121", null, null);
        assertStatus("danger", "heart_rate", "49", null, null);
        assertStatus("warning", "heart_rate", "101", null, null);
        assertStatus("warning", "heart_rate", "59", null, null);
        assertStatus("normal", "heart_rate", "80", null, null);
        assertStatus("normal", "weight", "60", null, null);
    }

    @Test
    void coversNullableFormattingAndRangeParsing() {
        assertThat((int) invoke("resolveDays", 365, null)).isEqualTo(365);
        assertThat((int) invoke("resolveDays", null, null)).isEqualTo(7);
        assertThat((int) invoke("resolveDays", null, " ")).isEqualTo(7);
        assertThatThrownBy(() -> invoke("resolveDays", 366, null)).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> invoke("resolveDays", null, "999999999999999999999d"))
                .isInstanceOf(IllegalArgumentException.class);

        assertThat((String) invoke("normalizeType", " weight ")).isEqualTo("weight");
        assertThatThrownBy(() -> invoke("normalizeType", (Object) null)).isInstanceOf(IllegalArgumentException.class);

        HealthRecord pressure = record("blood_pressure", null, null);
        pressure.setSystolic(120);
        pressure.setDiastolic(null);
        assertThat((String) invoke("displayValue", pressure)).isEqualTo("120");
        pressure.setSystolic(null);
        assertThat((String) invoke("displayValue", pressure)).isNotBlank();

        HealthRecord latest = record("weight", null, null);
        HealthRecord previous = record("weight", null, BigDecimal.ONE);
        assertThat((String) invoke("trendText", latest, previous)).isEqualTo("0");
        latest.setValue(BigDecimal.ONE);
        assertThat((String) invoke("trendText", latest, previous)).isEqualTo("0");
    }

    private void assertStatus(String expected, String type, String value, Integer systolic, Integer diastolic) {
        BigDecimal number = value == null ? null : new BigDecimal(value);
        assertThat((String) invoke("evaluateStatus", type, number, systolic, diastolic)).isEqualTo(expected);
    }

    private HealthRecord record(String type, BigDecimal value, BigDecimal value1) {
        HealthRecord record = new HealthRecord();
        record.setType(type);
        record.setValue(value);
        record.setValue1(value1);
        return record;
    }

    private <T> T invoke(String name, Object... args) {
        return ReflectionTestUtils.invokeMethod(service, name, args);
    }
}

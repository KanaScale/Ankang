package com.ankang.assistant.agent.tool;

import com.ankang.assistant.agent.action.AgentActionExecutionContext;
import com.ankang.assistant.agent.action.AgentActionValidator;
import com.ankang.assistant.eventmesh.service.RiskEngineService;
import com.ankang.assistant.eventmesh.vo.RiskAssessment;
import com.ankang.assistant.health.dto.HealthRecordCreateDTO;
import com.ankang.assistant.health.service.HealthService;
import com.ankang.assistant.health.vo.HealthRecordVO;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.doThrow;

class RecordHealthDataToolTest {

    @Test
    void savesHealthDataAfterConfirmation() {
        HealthService healthService = mock(HealthService.class);
        RiskEngineService riskEngineService = mock(RiskEngineService.class);
        when(healthService.createRecord(any(HealthRecordCreateDTO.class))).thenReturn(record(10L));
        when(riskEngineService.assess(42L, 10L)).thenReturn(new RiskAssessment(
                "high", 78, "血压明显偏高", List.of("血压明显偏高")
        ));
        RecordHealthDataTool tool = new RecordHealthDataTool(
                healthService, riskEngineService, new AgentActionValidator());

        var result = tool.executeAction(patientContext(), Map.of("systolic", 160, "diastolic", 100));

        assertThat(result.success()).isTrue();
        assertThat(result.data()).containsKeys("healthRecords", "risk");
        verify(healthService).createRecord(any(HealthRecordCreateDTO.class));
    }

    @Test
    void rejectsAbnormalValueWithoutSaving() {
        HealthService healthService = mock(HealthService.class);
        RecordHealthDataTool tool = new RecordHealthDataTool(
                healthService, mock(RiskEngineService.class), new AgentActionValidator());

        var result = tool.executeAction(patientContext(), Map.of("heartRate", 500));

        assertThat(result.success()).isFalse();
        verify(healthService, never()).createRecord(any());
    }

    @Test
    void triggersRiskAssessmentAfterSave() {
        HealthService healthService = mock(HealthService.class);
        RiskEngineService riskEngineService = mock(RiskEngineService.class);
        when(healthService.createRecord(any(HealthRecordCreateDTO.class))).thenReturn(record(11L));
        when(riskEngineService.assess(42L, 11L)).thenReturn(new RiskAssessment(
                "elevated", 45, "心率偏快", List.of("心率处于偏快或偏慢状态")
        ));
        RecordHealthDataTool tool = new RecordHealthDataTool(
                healthService, riskEngineService, new AgentActionValidator());

        tool.executeAction(patientContext(), Map.of("heartRate", 108));

        verify(riskEngineService).assess(42L, 11L);
    }

    @Test
    void assessesEverySavedMetricAndReturnsTheHighestRisk() {
        HealthService healthService = mock(HealthService.class);
        RiskEngineService riskEngineService = mock(RiskEngineService.class);
        when(healthService.createRecord(any(HealthRecordCreateDTO.class))).thenReturn(
                record(20L, "blood_pressure"),
                record(21L, "heart_rate")
        );
        when(riskEngineService.assess(42L, 20L)).thenReturn(new RiskAssessment(
                "high", 78, "血压明显偏高", List.of("血压明显偏高")
        ));
        when(riskEngineService.assess(42L, 21L)).thenReturn(new RiskAssessment(
                "elevated", 25, "心率偏快", List.of("心率处于偏快或偏慢状态")
        ));
        RecordHealthDataTool tool = new RecordHealthDataTool(
                healthService, riskEngineService, new AgentActionValidator());

        var result = tool.executeAction(patientContext(), Map.of(
                "systolic", 160,
                "diastolic", 100,
                "heartRate", 108
        ));

        assertThat(result.success()).isTrue();
        assertThat(result.data().get("risk").toString()).contains("riskLevel=high");
        assertThat(result.data().get("riskAssessments").toString()).contains("血压明显偏高", "心率偏快");
        verify(riskEngineService).assess(42L, 20L);
        verify(riskEngineService).assess(42L, 21L);
    }

    @Test
    void metadataCaregiverGuardAndValidationFailureAreCovered() {
        HealthService health = mock(HealthService.class);
        AgentActionValidator validator = mock(AgentActionValidator.class);
        RecordHealthDataTool tool = new RecordHealthDataTool(
                health, mock(RiskEngineService.class), validator);

        assertThat(tool.name()).isEqualTo("record_health_data");
        assertThat(tool.description()).isNotBlank();
        assertThat(tool.execute(Map.of()).success()).isFalse();
        assertThat(tool.supportsAction(com.ankang.assistant.agent.action.AgentActionType.RECORD_HEALTH_DATA))
                .isTrue();
        assertThat(tool.supportsAction(com.ankang.assistant.agent.action.AgentActionType.CREATE_HEALTH_PLAN))
                .isFalse();

        AgentActionExecutionContext caregiver =
                new AgentActionExecutionContext("a", 7L, 42L, 1L, "CAREGIVER");
        assertThat(tool.executeAction(caregiver, Map.of("heartRate", 70)).success()).isFalse();
        verify(health, never()).createRecord(any());

        doThrow(new IllegalArgumentException("invalid metric")).when(validator)
                .validateForExecution(any(), any(), any());
        assertThat(tool.executeAction(patientContext(), Map.of("heartRate", 70)).resultMessage())
                .contains("invalid metric");
    }

    @Test
    void allSingleValueMetricsAndEmptySaveFallbackAreCovered() {
        HealthService health = mock(HealthService.class);
        when(health.createRecord(any())).thenReturn(record(30L, "heart_rate"));
        RiskEngineService risk = mock(RiskEngineService.class);
        when(risk.assess(any(), any())).thenReturn(null);
        RecordHealthDataTool tool = new RecordHealthDataTool(
                health, risk, new AgentActionValidator());

        var result = tool.executeAction(patientContext(), Map.of(
                "heartRate", 70,
                "bloodGlucose", new BigDecimal("5.6"),
                "weight", new BigDecimal("65.5"),
                "remark", "morning"
        ));
        assertThat(result.success()).isTrue();
        assertThat(result.data()).containsKey("riskError");
        verify(health, org.mockito.Mockito.times(3)).createRecord(any());

        AgentActionValidator permissive = mock(AgentActionValidator.class);
        var empty = new RecordHealthDataTool(health, risk, permissive)
                .executeAction(patientContext(), Map.of());
        assertThat(empty.success()).isFalse();
    }

    @Test
    void riskFailureAndNormalSuggestionBranchDoNotUndoSavedRecords() {
        HealthService health = mock(HealthService.class);
        when(health.createRecord(any())).thenReturn(record(40L, "heart_rate"));
        RiskEngineService unavailable = mock(RiskEngineService.class);
        when(unavailable.assess(42L, 40L)).thenThrow(new IllegalStateException("offline"));
        var degraded = new RecordHealthDataTool(
                health, unavailable, new AgentActionValidator())
                .executeAction(patientContext(), Map.of("heartRate", 70));
        assertThat(degraded.success()).isTrue();
        assertThat(degraded.data()).containsKey("riskError");

        RiskEngineService normal = mock(RiskEngineService.class);
        when(normal.assess(42L, 40L)).thenReturn(
                new RiskAssessment("normal", 5, "正常", List.of()));
        var normalResult = new RecordHealthDataTool(
                health, normal, new AgentActionValidator())
                .executeAction(patientContext(), Map.of("heartRate", 70));
        assertThat(normalResult.data().get("risk").toString()).contains("继续保持规律记录");
    }

    private AgentActionExecutionContext patientContext() {
        return new AgentActionExecutionContext("act_test", 42L, 42L, 7L, "PATIENT");
    }

    private HealthRecordVO record(Long id) {
        return record(id, "blood_pressure");
    }

    private HealthRecordVO record(Long id, String type) {
        if ("heart_rate".equals(type)) {
            return new HealthRecordVO(
                    id, "heart_rate", BigDecimal.valueOf(108), BigDecimal.valueOf(108),
                    null, null, null, "bpm", "warning", "agent_action",
                    "", LocalDateTime.now()
            );
        }
        return new HealthRecordVO(
                id, "blood_pressure", BigDecimal.valueOf(160), BigDecimal.valueOf(160),
                BigDecimal.valueOf(100), 160, 100, "mmHg", "danger", "agent_action",
                "", LocalDateTime.now()
        );
    }
}

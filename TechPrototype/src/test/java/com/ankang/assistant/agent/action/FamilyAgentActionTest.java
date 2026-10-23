package com.ankang.assistant.agent.action;

import com.ankang.assistant.agent.tool.AgentToolExecutor;
import com.ankang.assistant.family.service.FamilyPermissionService;
import com.ankang.assistant.family.service.FamilyService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class FamilyAgentActionTest {

    @Test
    void caregiverCanEvaluateBoundPatientRisk() {
        AgentActionMapper mapper = mock(AgentActionMapper.class);
        AgentToolExecutor executor = mock(AgentToolExecutor.class);
        FamilyPermissionService permissionService = mock(FamilyPermissionService.class);
        when(permissionService.hasCaregiverAccess(7L, 42L, FamilyService.ASK_AGENT)).thenReturn(true);
        when(mapper.insert(any(AgentAction.class))).thenAnswer(invocation -> {
            AgentAction action = invocation.getArgument(0);
            action.setId(1L);
            return 1;
        });
        when(executor.executeAction(any(), any(), any())).thenReturn(
                AgentActionResult.success("风险评估完成", Map.of("risk", Map.of("riskLevel", "normal")))
        );
        AgentActionService service = new AgentActionService(
                mapper, executor, new AgentActionValidator(), new ObjectMapper(), permissionService);

        AgentActionVO result = service.executeImmediate(
                7L, 42L, "CAREGIVER", 9L,
                new AgentActionRequest(
                        AgentActionType.EVALUATE_HEALTH_RISK,
                        "健康风险评估",
                        "评估",
                        false,
                        Map.of()
                )
        );

        assertThat(result.status()).isEqualTo("EXECUTED");
    }

    @Test
    void caregiverCannotModifyPatientHealthData() {
        AgentActionService service = new AgentActionService(
                mock(AgentActionMapper.class),
                mock(AgentToolExecutor.class),
                new AgentActionValidator(),
                new ObjectMapper(),
                allowedPermissionService()
        );

        assertThatThrownBy(() -> service.createPendingAction(
                7L, 42L, "CAREGIVER", 9L,
                new AgentActionRequest(
                        AgentActionType.RECORD_HEALTH_DATA,
                        "确认录入",
                        "血压",
                        true,
                        Map.of("systolic", 160, "diastolic", 100)
                )
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("家属版 Agent 不能直接修改");
    }

    private FamilyPermissionService allowedPermissionService() {
        FamilyPermissionService permissionService = mock(FamilyPermissionService.class);
        when(permissionService.hasCaregiverAccess(7L, 42L, FamilyService.ASK_AGENT)).thenReturn(true);
        return permissionService;
    }
}

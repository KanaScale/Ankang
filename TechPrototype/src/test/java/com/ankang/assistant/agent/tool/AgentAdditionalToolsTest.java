package com.ankang.assistant.agent.tool;

import com.ankang.assistant.agent.action.AgentActionExecutionContext;
import com.ankang.assistant.agent.action.AgentActionResult;
import com.ankang.assistant.agent.action.AgentActionType;
import com.ankang.assistant.agent.config.AgentProperties;
import com.ankang.assistant.emergency.service.NearbyHospitalService;
import com.ankang.assistant.emergency.vo.NearbyHospitalVO;
import com.ankang.assistant.eventmesh.service.RiskEngineService;
import com.ankang.assistant.eventmesh.vo.RiskAssessment;
import com.ankang.assistant.family.service.FamilyService;
import com.ankang.assistant.family.vo.FamilyCaregiverContactVO;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyDouble;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class AgentAdditionalToolsTest {

    private final AgentActionExecutionContext context =
            new AgentActionExecutionContext("action", 42L, 7L, 1L, "PATIENT");

    @Test
    void nearbyHospitalToolCoversMissingCoordinatesRealResultsAndFallback() {
        NearbyHospitalService hospitalService = mock(NearbyHospitalService.class);
        NearbyHospitalTool tool = new NearbyHospitalTool(hospitalService);
        assertThat(tool.name()).isEqualTo("nearby_hospital");
        assertThat(tool.description()).isNotBlank();
        assertThat(tool.execute(Map.of()).success()).isFalse();
        assertThat(tool.supportsAction(AgentActionType.SEARCH_NEARBY_HOSPITALS)).isTrue();
        assertThat(tool.supportsAction(AgentActionType.RECORD_HEALTH_DATA)).isFalse();

        AgentActionResult missing = tool.executeAction(context, Map.of());
        assertThat(missing.success()).isTrue();
        assertThat(missing.resultMessage()).isNotBlank();

        NearbyHospitalVO real = new NearbyHospitalVO(
                "amap", "gcj02", 1000,
                List.of(new NearbyHospitalVO.HospitalVO(
                        "1", "医院", "地址", 100, "100m", "1", 31.0, 121.0, "医院", "amap"
                ))
        );
        when(hospitalService.findNearby(31.0, 121.0, 1000)).thenReturn(real);
        AgentActionResult found = tool.executeAction(context, Map.of(
                "latitude", 31.0, "longitude", 121.0, "radiusMeters", 1000
        ));
        assertThat(found.resultMessage()).isNotBlank();

        when(hospitalService.findNearby(anyDouble(), anyDouble(), anyInt()))
                .thenThrow(new IllegalStateException("offline"));
        AgentActionResult fallback = tool.executeAction(context, Map.of(
                "latitude", "31.2", "longitude", "121.5"
        ));
        assertThat((List<?>) fallback.data().get("nearbyHospitals")).hasSize(3);
    }

    @Test
    void evaluateRiskToolBuildsSuggestionsForEveryLevel() {
        RiskEngineService riskService = mock(RiskEngineService.class);
        EvaluateHealthRiskTool tool = new EvaluateHealthRiskTool(riskService);
        assertThat(tool.name()).isEqualTo("evaluate_health_risk");
        assertThat(tool.description()).isNotBlank();
        assertThat(tool.execute(Map.of()).success()).isFalse();
        assertThat(tool.supportsAction(AgentActionType.EVALUATE_HEALTH_RISK)).isTrue();

        for (String level : List.of("normal", "elevated", "high")) {
            when(riskService.assess(7L)).thenReturn(
                    new RiskAssessment(level, 50, level, List.of("reason"))
            );
            AgentActionResult result = tool.executeAction(context, Map.of());
            @SuppressWarnings("unchecked")
            Map<String, Object> risk = (Map<String, Object>) result.data().get("risk");
            assertThat(risk.get("riskLevel")).isEqualTo(level);
            assertThat((List<?>) risk.get("suggestions")).isNotEmpty();
            assertThat((List<?>) risk.get("recommendedActions")).isNotEmpty();
        }
    }

    @Test
    void notifyFamilyToolCreatesPreviewWithAndWithoutContacts() {
        FamilyService familyService = mock(FamilyService.class);
        NotifyFamilyPreviewTool tool = new NotifyFamilyPreviewTool(familyService);
        assertThat(tool.name()).isEqualTo("notify_family_preview");
        assertThat(tool.description()).isNotBlank();
        assertThat(tool.execute(Map.of()).success()).isFalse();
        assertThat(tool.supportsAction(AgentActionType.NOTIFY_FAMILY_PREVIEW)).isTrue();

        when(familyService.listCaregiversForPatient(7L)).thenReturn(List.of());
        AgentActionResult empty = tool.executeAction(context, Map.of());
        assertThat(empty.resultMessage()).isNotBlank();
        assertThat(empty.data().get("sent")).isEqualTo(false);

        when(familyService.listCaregiversForPatient(7L)).thenReturn(List.of(
                new FamilyCaregiverContactVO(8L, "家属", "family", "138")
        ));
        AgentActionResult present = tool.executeAction(context, Map.of());
        assertThat(present.resultMessage()).isNotBlank();
    }

    @Test
    void webSearchToolAndExecutorCoverDisabledBlankSuccessFailureAndActions() {
        WebSearchClient client = mock(WebSearchClient.class);
        AgentProperties properties = new AgentProperties();
        WebSearchTool searchTool = new WebSearchTool(client, properties);
        properties.getWebSearch().setEnabled(false);
        assertThat(searchTool.execute(Map.of("query", "健康")).webSearchResults()).isEmpty();

        properties.getWebSearch().setEnabled(true);
        assertThat(searchTool.execute(null).webSearchResults()).isEmpty();
        assertThat(searchTool.execute(Map.of("query", " ")).webSearchResults()).isEmpty();

        WebSearchResult hit = new WebSearchResult(
                "title", "https://example.test", "summary", "test-provider"
        );
        when(client.search("健康", 5)).thenReturn(List.of(hit));
        assertThat(searchTool.execute(Map.of("query", "健康")).webSearchResults()).containsExactly(hit);
        when(client.search("失败", 5)).thenThrow(new IllegalStateException("provider down"));
        assertThat(searchTool.execute(Map.of("query", "失败")).errorMessage()).contains("provider down");

        AgentToolExecutor emptyExecutor = new AgentToolExecutor(List.of());
        assertThat(emptyExecutor.execute(null)).isEmpty();
        assertThat(emptyExecutor.execute(new ToolCallRequest(null, Map.of()))).isEmpty();
        assertThat(emptyExecutor.execute(new ToolCallRequest("missing", Map.of()))).isEmpty();
        assertThat(emptyExecutor.webSearch("x")).isEmpty();
        assertThat(emptyExecutor.executeAction(null, context, Map.of()).success()).isFalse();
        assertThat(emptyExecutor.executeAction(
                AgentActionType.RECORD_HEALTH_DATA, context, Map.of()
        ).success()).isFalse();

        AgentToolExecutor executor = new AgentToolExecutor(List.of(searchTool));
        when(client.search("健康", 5)).thenReturn(List.of(hit));
        assertThat(executor.webSearch("健康")).containsExactly(hit);
    }

    @Test
    void actionExecutionContextClassifiesActors() {
        assertThat(context.patientActor()).isTrue();
        assertThat(context.caregiverActor()).isFalse();
        AgentActionExecutionContext caregiver =
                new AgentActionExecutionContext("a", 1L, 2L, 3L, "CAREGIVER");
        assertThat(caregiver.patientActor()).isFalse();
        assertThat(caregiver.caregiverActor()).isTrue();
    }
}

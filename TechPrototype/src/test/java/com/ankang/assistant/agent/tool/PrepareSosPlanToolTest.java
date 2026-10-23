package com.ankang.assistant.agent.tool;

import com.ankang.assistant.agent.action.AgentActionExecutionContext;
import com.ankang.assistant.emergency.service.EmergencyService;
import com.ankang.assistant.emergency.vo.EmergencyContactVO;
import com.ankang.assistant.emergency.vo.NearbyHospitalVO;
import com.ankang.assistant.family.service.FamilyService;
import com.ankang.assistant.family.vo.FamilyCaregiverContactVO;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyDouble;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class PrepareSosPlanToolTest {

    @Test
    void returnsNearbyHospitalsAndFamilyContactsWithoutSendingSos() {
        NearbyHospitalTool nearbyHospitalTool = mock(NearbyHospitalTool.class);
        EmergencyService emergencyService = mock(EmergencyService.class);
        FamilyService familyService = mock(FamilyService.class);
        when(nearbyHospitalTool.findHospitals(Map.of("latitude", 31.2, "longitude", 121.5))).thenReturn(
                new NearbyHospitalVO("mock", "wgs84", 5000, List.of(new NearbyHospitalVO.HospitalVO(
                        "h1", "市人民医院", "地址", 1200, "1.2km", null, 31.2, 121.5, "医院", "mock"
                )))
        );
        when(familyService.listCaregiversForPatient(42L)).thenReturn(List.of(
                new FamilyCaregiverContactVO(7L, "家属", "child", "13800000000")
        ));
        when(emergencyService.listContactsByUserId(42L)).thenReturn(List.of(
                new EmergencyContactVO(
                        1L, null, "联系人", "家人", "家人",
                        "13800000001", 1, null, "MOBILE", true
                )
        ));
        PrepareSosPlanTool tool = new PrepareSosPlanTool(nearbyHospitalTool, emergencyService, familyService);

        var result = tool.executeAction(patientContext(), Map.of("latitude", 31.2, "longitude", 121.5));

        assertThat(result.success()).isTrue();
        assertThat(result.data()).containsKeys("nearbyHospitals", "familyContacts", "recommendedMessage");
        assertThat(result.resultMessage()).contains("尚未发起 SOS");
        verify(emergencyService, never()).createSosEvent(null);
    }

    private AgentActionExecutionContext patientContext() {
        return new AgentActionExecutionContext("act_sos", 42L, 42L, 7L, "PATIENT");
    }
}

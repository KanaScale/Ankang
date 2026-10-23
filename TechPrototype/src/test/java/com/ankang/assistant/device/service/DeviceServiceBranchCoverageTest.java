package com.ankang.assistant.device.service;

import com.ankang.assistant.device.dto.DeviceCustomSyncDTO;
import com.ankang.assistant.device.mapper.DeviceBindMapper;
import com.ankang.assistant.device.vo.DeviceRiskAlertVO;
import com.ankang.assistant.eventmesh.service.RiskEngineService;
import com.ankang.assistant.health.service.HealthService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;

class DeviceServiceBranchCoverageTest {

    private DeviceService service;

    @BeforeEach
    void setUp() {
        service = new DeviceService(mock(DeviceBindMapper.class), mock(HealthService.class),
                mock(RiskEngineService.class));
    }

    @Test
    void coversEveryCustomMetricStatusBoundary() {
        assertStatuses(new DeviceCustomSyncDTO(new BigDecimal("121"), null, null, null, null, null), "warning");
        assertStatuses(new DeviceCustomSyncDTO(new BigDecimal("49"), null, null, null, null, null), "warning");
        assertStatuses(new DeviceCustomSyncDTO(new BigDecimal("80"), null, null, null, null, null), "normal");

        assertStatuses(new DeviceCustomSyncDTO(null, 140, 80, null, null, null), "warning");
        assertStatuses(new DeviceCustomSyncDTO(null, 120, 90, null, null, null), "warning");
        assertStatuses(new DeviceCustomSyncDTO(null, 89, 70, null, null, null), "warning");
        assertStatuses(new DeviceCustomSyncDTO(null, 120, 59, null, null, null), "warning");
        assertStatuses(new DeviceCustomSyncDTO(null, 120, 80, null, null, null), "normal");

        assertStatuses(new DeviceCustomSyncDTO(null, null, null, new BigDecimal("6.2"), null, null), "warning");
        assertStatuses(new DeviceCustomSyncDTO(null, null, null, new BigDecimal("3.8"), null, null), "warning");
        assertStatuses(new DeviceCustomSyncDTO(null, null, null, new BigDecimal("5"), null, null), "normal");
        assertStatuses(new DeviceCustomSyncDTO(null, null, null, null, null, new BigDecimal("5.9")), "warning");
        assertStatuses(new DeviceCustomSyncDTO(null, null, null, null, null, new BigDecimal("7")), "normal");
    }

    @Test
    void coversInvalidPressureAndRangeShortCircuits() {
        for (DeviceCustomSyncDTO dto : List.of(
                new DeviceCustomSyncDTO(null, null, 80, null, null, null),
                new DeviceCustomSyncDTO(null, 39, 30, null, null, null),
                new DeviceCustomSyncDTO(null, 301, 80, null, null, null),
                new DeviceCustomSyncDTO(null, 120, 29, null, null, null),
                new DeviceCustomSyncDTO(null, 220, 201, null, null, null),
                new DeviceCustomSyncDTO(null, 80, 80, null, null, null)
        )) {
            assertThatThrownBy(() -> customMetrics(dto)).isInstanceOf(IllegalArgumentException.class);
        }
        assertThatThrownBy(() -> invoke("requireRange", BigDecimal.ZERO, "x", BigDecimal.ONE, BigDecimal.TEN))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> invoke("requireRange", new BigDecimal("11"), "x", BigDecimal.ONE, BigDecimal.TEN))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void coversRiskReplacementNullsRanksAndScores() {
        DeviceRiskAlertVO elevated0 = alert("elevated", null);
        DeviceRiskAlertVO elevated1 = alert("elevated", 1);
        DeviceRiskAlertVO high = alert("high", 1);
        assertThat((boolean) invoke("shouldReplaceAlert", elevated0, null)).isFalse();
        assertThat((boolean) invoke("shouldReplaceAlert", elevated0, alert("normal", 99))).isFalse();
        assertThat((boolean) invoke("shouldReplaceAlert", elevated0, high)).isTrue();
        assertThat((boolean) invoke("shouldReplaceAlert", high, elevated1)).isFalse();
        assertThat((boolean) invoke("shouldReplaceAlert", elevated0, elevated1)).isTrue();
        assertThat((boolean) invoke("shouldReplaceAlert", elevated1, elevated0)).isFalse();
        assertThat((boolean) invoke("requiresAttention", "high")).isTrue();
        assertThat((boolean) invoke("requiresAttention", (Object) null)).isFalse();
    }

    private void assertStatuses(DeviceCustomSyncDTO dto, String expected) {
        assertThat(customMetrics(dto)).extracting("status").containsExactly(expected);
    }

    @SuppressWarnings("unchecked")
    private List<Object> customMetrics(DeviceCustomSyncDTO dto) {
        return invoke("customMetrics", dto);
    }

    private DeviceRiskAlertVO alert(String level, Integer score) {
        return new DeviceRiskAlertVO("id", "type", 1L, "completed", level, score,
                "summary", List.of(), null, LocalDateTime.now(), LocalDateTime.now(), List.of());
    }

    private <T> T invoke(String name, Object... args) {
        return ReflectionTestUtils.invokeMethod(service, name, args);
    }
}

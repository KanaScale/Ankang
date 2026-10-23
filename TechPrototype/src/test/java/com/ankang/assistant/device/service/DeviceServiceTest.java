package com.ankang.assistant.device.service;

import com.ankang.assistant.config.JwtService;
import com.ankang.assistant.device.dto.DeviceCustomSyncDTO;
import com.ankang.assistant.device.dto.DeviceSignalDTO;
import com.ankang.assistant.device.entity.DeviceBind;
import com.ankang.assistant.device.mapper.DeviceBindMapper;
import com.ankang.assistant.device.vo.DeviceRiskAlertVO;
import com.ankang.assistant.eventmesh.service.RiskEngineService;
import com.ankang.assistant.eventmesh.vo.RiskAssessment;
import com.ankang.assistant.health.dto.HealthRecordCreateDTO;
import com.ankang.assistant.health.service.HealthService;
import com.ankang.assistant.health.vo.HealthRecordVO;
import com.baomidou.mybatisplus.core.MybatisConfiguration;
import com.baomidou.mybatisplus.core.metadata.TableInfoHelper;
import org.apache.ibatis.builder.MapperBuilderAssistant;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.concurrent.atomic.AtomicLong;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class DeviceServiceTest {

    @Mock DeviceBindMapper deviceBindMapper;
    @Mock HealthService healthService;
    @Mock RiskEngineService riskEngineService;

    private DeviceService service;

    @BeforeEach
    void setUp() {
        TableInfoHelper.initTableInfo(
                new MapperBuilderAssistant(new MybatisConfiguration(), ""), DeviceBind.class
        );
        service = new DeviceService(deviceBindMapper, healthService, riskEngineService);
        JwtService.JwtUser principal = new JwtService.JwtUser(42L, "device-user");
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(principal, null, List.of())
        );
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void getsExistingDeviceAndMergesLatestMetricsWithFallbacks() {
        DeviceBind device = device(8L);
        when(deviceBindMapper.selectOne(any())).thenReturn(device);
        when(healthService.listRecentRecordsByUserId(42L, 20)).thenReturn(List.of(
                record(1L, "heart_rate", "88", null, null, "warning"),
                record(2L, "heart_rate", "70", null, null, "normal"),
                record(3L, "unknown", "1", null, null, "normal")
        ));

        var result = service.getCurrentDevice();

        assertThat(result.id()).isEqualTo(8L);
        assertThat(result.metrics()).hasSize(5);
        assertThat(result.metrics().get(0).value()).isEqualByComparingTo("88");
        assertThat(result.writtenRecordIds()).isEmpty();
    }

    @Test
    void createsMockDeviceAndSynchronizesMetricsWithHighestRiskAlert() {
        when(deviceBindMapper.selectOne(any())).thenReturn(null);
        when(deviceBindMapper.insert(any(DeviceBind.class))).thenAnswer(invocation -> {
            DeviceBind device = invocation.getArgument(0);
            device.setId(9L);
            return 1;
        });

        AtomicLong ids = new AtomicLong(100);
        when(healthService.createRecord(any(HealthRecordCreateDTO.class))).thenAnswer(invocation -> {
            HealthRecordCreateDTO dto = invocation.getArgument(0);
            return new HealthRecordVO(
                    ids.incrementAndGet(), dto.type(), dto.value(), dto.value1(), dto.value2(),
                    dto.systolic(), dto.diastolic(), dto.unit(), "normal", dto.source(),
                    dto.remark(), dto.recordedAt()
            );
        });
        when(riskEngineService.assess(eq(42L), anyLong())).thenReturn(
                risk("normal", 10),
                risk("elevated", 50),
                risk("elevated", 70),
                risk("high", 80),
                risk("high", 90)
        );

        var result = service.mockSync();

        assertThat(result.id()).isEqualTo(9L);
        assertThat(result.metrics()).hasSize(5);
        assertThat(result.writtenRecordIds()).hasSize(5);
        assertThat(result.riskAlert()).isNotNull();
        assertThat(result.riskAlert().riskLevel()).isEqualTo("high");
        assertThat(result.riskAlert().riskScore()).isEqualTo(90);
        verify(deviceBindMapper).updateById(any(DeviceBind.class));
    }

    @Test
    void customSyncValidatesAndWritesEverySupportedMetric() {
        DeviceBind device = device(10L);
        when(deviceBindMapper.selectOne(any())).thenReturn(device);
        AtomicLong ids = new AtomicLong(200);
        when(healthService.createRecord(any())).thenAnswer(invocation -> {
            HealthRecordCreateDTO dto = invocation.getArgument(0);
            return new HealthRecordVO(
                    ids.incrementAndGet(), dto.type(), dto.value(), dto.value1(), dto.value2(),
                    dto.systolic(), dto.diastolic(), dto.unit(), "warning", dto.source(),
                    dto.remark(), dto.recordedAt()
            );
        });
        when(riskEngineService.assess(anyLong(), anyLong())).thenReturn(risk("normal", 0));
        when(healthService.listRecentRecordsByUserId(42L, 20)).thenReturn(List.of());

        var result = service.customSync(new DeviceCustomSyncDTO(
                new BigDecimal("49"), 145, 95, new BigDecimal("6.2"),
                new BigDecimal("1234.9"), new BigDecimal("5.5")
        ));

        assertThat(result.writtenRecordIds()).hasSize(5);
        assertThat(result.writtenRecordTypes()).containsExactly(
                "heart_rate", "blood_pressure", "blood_glucose", "steps", "sleep_hours"
        );
        assertThat(result.riskAlert()).isNull();

        assertThatThrownBy(() -> service.customSync(null)).hasMessageContaining("填写手环数据");
        assertThatThrownBy(() -> service.customSync(new DeviceCustomSyncDTO(
                null, null, null, null, null, null
        ))).hasMessageContaining("至少填写");
        assertThatThrownBy(() -> service.customSync(new DeviceCustomSyncDTO(
                new BigDecimal("10"), null, null, null, null, null
        ))).hasMessageContaining("心率");
        assertThatThrownBy(() -> service.customSync(new DeviceCustomSyncDTO(
                null, 120, null, null, null, null
        ))).hasMessageContaining("同时填写");
        assertThatThrownBy(() -> service.customSync(new DeviceCustomSyncDTO(
                null, 70, 90, null, null, null
        ))).hasMessageContaining("血压范围");
        assertThatThrownBy(() -> service.customSync(new DeviceCustomSyncDTO(
                null, null, null, new BigDecimal("31"), null, null
        ))).hasMessageContaining("血糖");
        assertThatThrownBy(() -> service.customSync(new DeviceCustomSyncDTO(
                null, null, null, null, BigDecimal.ZERO, null
        ))).hasMessageContaining("步数");
        assertThatThrownBy(() -> service.customSync(new DeviceCustomSyncDTO(
                null, null, null, null, null, new BigDecimal("25")
        ))).hasMessageContaining("睡眠");
    }

    @Test
    void sendsAllSignalKindsAndCoversRiskComparisonHelpers() {
        when(deviceBindMapper.selectOne(any())).thenReturn(device(11L));

        assertThat(service.sendSignal(null).lastSignal().signalType()).isEqualTo("ping");
        assertThat(service.sendSignal(new DeviceSignalDTO(" locate ", null)).lastSignal().message())
                .contains("定位");
        assertThat(service.sendSignal(new DeviceSignalDTO("VIBRATE", null)).lastSignal().message())
                .contains("震动");
        assertThat(service.sendSignal(new DeviceSignalDTO("sync", null)).lastSignal().message())
                .contains("同步");
        assertThat(service.sendSignal(new DeviceSignalDTO("other", null)).lastSignal().signalType())
                .isEqualTo("custom");

        DeviceRiskAlertVO high80 = alert("high", 80);
        DeviceRiskAlertVO high90 = alert("high", 90);
        DeviceRiskAlertVO elevated = alert("elevated", 50);
        DeviceRiskAlertVO normal = alert("normal", null);
        assertThat((boolean) ReflectionTestUtils.invokeMethod(service, "shouldReplaceAlert", null, normal)).isFalse();
        assertThat((boolean) ReflectionTestUtils.invokeMethod(service, "shouldReplaceAlert", null, elevated)).isTrue();
        assertThat((boolean) ReflectionTestUtils.invokeMethod(service, "shouldReplaceAlert", high80, high90)).isTrue();
        assertThat((boolean) ReflectionTestUtils.invokeMethod(service, "shouldReplaceAlert", high90, high80)).isFalse();
        assertThat((int) ReflectionTestUtils.invokeMethod(service, "riskRank", "normal")).isZero();
        assertThat((int) ReflectionTestUtils.invokeMethod(service, "safeScore", (Object) null)).isZero();
        assertThat((String) ReflectionTestUtils.invokeMethod(service, "metricLabel", "unknown")).isEqualTo("指标");
    }

    private DeviceBind device(Long id) {
        DeviceBind device = new DeviceBind();
        device.setId(id);
        device.setUserId(42L);
        device.setDeviceName("测试手环");
        device.setDeviceType("wearable");
        device.setProvider("mock");
        device.setBindStatus("active");
        device.setLastSyncAt(LocalDateTime.now());
        return device;
    }

    private HealthRecordVO record(Long id, String type, String value, Integer systolic,
                                  Integer diastolic, String status) {
        BigDecimal decimal = value == null ? null : new BigDecimal(value);
        return new HealthRecordVO(
                id, type, decimal, decimal, null, systolic, diastolic,
                "unit", status, "device", null, LocalDateTime.now()
        );
    }

    private RiskAssessment risk(String level, int score) {
        return new RiskAssessment(level, score, level + " summary", List.of(level));
    }

    private DeviceRiskAlertVO alert(String level, Integer score) {
        return new DeviceRiskAlertVO(
                "id", "type", 1L, "completed", level, score, "summary",
                List.of(), null, LocalDateTime.now(), LocalDateTime.now(), List.of()
        );
    }
}

package com.ankang.assistant.device.service;

import com.ankang.assistant.config.SecurityUtils;
import com.ankang.assistant.device.dto.DeviceCustomSyncDTO;
import com.ankang.assistant.device.dto.DeviceSignalDTO;
import com.ankang.assistant.device.entity.DeviceBind;
import com.ankang.assistant.device.mapper.DeviceBindMapper;
import com.ankang.assistant.device.vo.DeviceMetricVO;
import com.ankang.assistant.device.vo.DeviceRiskAlertVO;
import com.ankang.assistant.device.vo.DeviceSignalVO;
import com.ankang.assistant.device.vo.DeviceSyncVO;
import com.ankang.assistant.eventmesh.service.RiskEngineService;
import com.ankang.assistant.eventmesh.vo.RiskAssessment;
import com.ankang.assistant.health.dto.HealthRecordCreateDTO;
import com.ankang.assistant.health.service.HealthService;
import com.ankang.assistant.health.vo.HealthRecordVO;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;

@Service
public class DeviceService {

    private final DeviceBindMapper deviceBindMapper;
    private final HealthService healthService;
    private final RiskEngineService riskEngineService;

    public DeviceService(DeviceBindMapper deviceBindMapper, HealthService healthService,
                         RiskEngineService riskEngineService) {
        this.deviceBindMapper = deviceBindMapper;
        this.healthService = healthService;
        this.riskEngineService = riskEngineService;
    }

    @Transactional
    public DeviceSyncVO getCurrentDevice() {
        Long userId = SecurityUtils.currentUserId();
        DeviceBind device = ensureMockDevice(userId);
        return toVO(device, latestMetrics(userId), null);
    }

    @Transactional
    public DeviceSyncVO mockSync() {
        Long userId = SecurityUtils.currentUserId();
        DeviceBind device = ensureMockDevice(userId);
        List<DeviceMetricVO> metrics = randomMetrics();
        LocalDateTime now = LocalDateTime.now();
        device.setBindStatus("active");
        device.setLastSyncAt(now);
        deviceBindMapper.updateById(device);
        DeviceRecordWriteResult writtenRecords = writeMetrics(userId, metrics, now);
        DeviceSignalVO signal = new DeviceSignalVO(
                newSignalId(),
                "sync",
                "sent",
                "模拟设备数据已同步并写入健康记录",
                now
        );
        return toVO(device, metrics, signal, writtenRecords);
    }

    @Transactional
    public DeviceSyncVO customSync(DeviceCustomSyncDTO dto) {
        Long userId = SecurityUtils.currentUserId();
        DeviceBind device = ensureMockDevice(userId);
        List<DeviceMetricVO> metrics = customMetrics(dto);
        if (metrics.isEmpty()) {
            throw new IllegalArgumentException("请至少填写一项手环数据");
        }
        LocalDateTime now = LocalDateTime.now();
        device.setBindStatus("active");
        device.setLastSyncAt(now);
        deviceBindMapper.updateById(device);
        DeviceRecordWriteResult writtenRecords = writeMetrics(userId, metrics, now, "手环自定义录入");
        DeviceSignalVO signal = new DeviceSignalVO(
                newSignalId(),
                "custom",
                "sent",
                "手环自定义数据已写入健康记录",
                now
        );
        return toVO(device, latestMetrics(userId), signal, writtenRecords);
    }

    @Transactional
    public DeviceSyncVO sendSignal(DeviceSignalDTO dto) {
        DeviceBind device = ensureMockDevice(SecurityUtils.currentUserId());
        LocalDateTime now = LocalDateTime.now();
        String signalType = normalizeSignalType(dto == null ? null : dto.signalType());
        device.setBindStatus("active");
        deviceBindMapper.updateById(device);
        DeviceSignalVO signal = new DeviceSignalVO(
                newSignalId(),
                signalType,
                "sent",
                signalMessage(signalType),
                now
        );
        return toVO(device, defaultMetrics(), signal);
    }

    private DeviceBind ensureMockDevice(Long userId) {
        DeviceBind existing = deviceBindMapper.selectOne(new LambdaQueryWrapper<DeviceBind>()
                .eq(DeviceBind::getUserId, userId)
                .orderByDesc(DeviceBind::getLastSyncAt)
                .orderByDesc(DeviceBind::getId)
                .last("LIMIT 1"));
        if (existing != null) {
            return existing;
        }
        DeviceBind device = new DeviceBind();
        device.setUserId(userId);
        device.setDeviceName("安康模拟手环");
        device.setDeviceType("wearable");
        device.setProvider("mock");
        device.setBindStatus("active");
        device.setLastSyncAt(LocalDateTime.now().minusMinutes(5));
        deviceBindMapper.insert(device);
        return device;
    }

    private List<DeviceMetricVO> defaultMetrics() {
        return List.of(
                metric("heart_rate", "心率", BigDecimal.valueOf(78), null, null, "bpm", "normal"),
                metric("blood_pressure", "血压", null, 128, 82, "mmHg", "normal"),
                metric("blood_glucose", "血糖", BigDecimal.valueOf(5.8), null, null, "mmol/L", "normal"),
                metric("steps", "步数", BigDecimal.valueOf(5200), null, null, "步", "normal"),
                metric("sleep_hours", "睡眠", BigDecimal.valueOf(6.8), null, null, "小时", "normal")
        );
    }

    private List<DeviceMetricVO> randomMetrics() {
        ThreadLocalRandom random = ThreadLocalRandom.current();
        int heartRate = random.nextInt(65, 96);
        int systolic = random.nextInt(112, 142);
        int diastolic = random.nextInt(70, 90);
        BigDecimal glucose = BigDecimal.valueOf(random.nextDouble(4.9, 7.2)).setScale(1, RoundingMode.HALF_UP);
        int steps = random.nextInt(2500, 9500);
        BigDecimal sleepHours = BigDecimal.valueOf(random.nextDouble(5.8, 8.4)).setScale(1, RoundingMode.HALF_UP);
        return List.of(
                metric("heart_rate", "心率", BigDecimal.valueOf(heartRate), null, null, "bpm",
                        heartRate > 90 ? "warning" : "normal"),
                metric("blood_pressure", "血压", null, systolic, diastolic, "mmHg",
                        systolic >= 135 || diastolic >= 85 ? "warning" : "normal"),
                metric("blood_glucose", "血糖", glucose, null, null, "mmol/L",
                        glucose.compareTo(BigDecimal.valueOf(6.1)) > 0 ? "warning" : "normal"),
                metric("steps", "步数", BigDecimal.valueOf(steps), null, null, "步", "normal"),
                metric("sleep_hours", "睡眠", sleepHours, null, null, "小时",
                        sleepHours.compareTo(BigDecimal.valueOf(6)) < 0 ? "warning" : "normal")
        );
    }

    private List<DeviceMetricVO> latestMetrics(Long userId) {
        Map<String, HealthRecordVO> latestByType = new LinkedHashMap<>();
        for (HealthRecordVO record : healthService.listRecentRecordsByUserId(userId, 20)) {
            latestByType.putIfAbsent(record.type(), record);
        }
        List<DeviceMetricVO> fallback = defaultMetrics();
        return fallback.stream()
                .map(metric -> latestByType.containsKey(metric.type())
                        ? fromRecord(latestByType.get(metric.type()))
                        : metric)
                .toList();
    }

    private List<DeviceMetricVO> customMetrics(DeviceCustomSyncDTO dto) {
        if (dto == null) {
            throw new IllegalArgumentException("请填写手环数据");
        }
        List<DeviceMetricVO> metrics = new ArrayList<>();
        if (dto.heartRate() != null) {
            BigDecimal value = requireRange(dto.heartRate(), "心率", new BigDecimal("30"), new BigDecimal("220"));
            metrics.add(metric("heart_rate", "心率", value, null, null, "bpm",
                    value.compareTo(new BigDecimal("120")) > 0 || value.compareTo(new BigDecimal("50")) < 0
                            ? "warning" : "normal"));
        }
        if (dto.systolic() != null || dto.diastolic() != null) {
            Integer systolic = dto.systolic();
            Integer diastolic = dto.diastolic();
            if (systolic == null || diastolic == null) {
                throw new IllegalArgumentException("血压需要同时填写收缩压和舒张压");
            }
            if (systolic < 40 || systolic > 300 || diastolic < 30 || diastolic > 200 || systolic <= diastolic) {
                throw new IllegalArgumentException("血压范围不合理，请填写正确的收缩压/舒张压");
            }
            metrics.add(metric("blood_pressure", "血压", null, systolic, diastolic, "mmHg",
                    systolic >= 140 || diastolic >= 90 || systolic < 90 || diastolic < 60 ? "warning" : "normal"));
        }
        if (dto.bloodGlucose() != null) {
            BigDecimal value = requireRange(dto.bloodGlucose(), "血糖", new BigDecimal("1"), new BigDecimal("30"));
            metrics.add(metric("blood_glucose", "血糖", value, null, null, "mmol/L",
                    value.compareTo(new BigDecimal("6.1")) > 0 || value.compareTo(new BigDecimal("3.9")) < 0
                            ? "warning" : "normal"));
        }
        if (dto.steps() != null) {
            BigDecimal value = requireRange(dto.steps(), "步数", BigDecimal.ONE, new BigDecimal("100000"));
            metrics.add(metric("steps", "步数", value.setScale(0, RoundingMode.DOWN), null, null, "步", "normal"));
        }
        if (dto.sleepHours() != null) {
            BigDecimal value = requireRange(dto.sleepHours(), "睡眠", new BigDecimal("0.5"), new BigDecimal("24"));
            metrics.add(metric("sleep_hours", "睡眠", value, null, null, "小时",
                    value.compareTo(new BigDecimal("6")) < 0 ? "warning" : "normal"));
        }
        return metrics;
    }

    private BigDecimal requireRange(BigDecimal value, String label, BigDecimal min, BigDecimal max) {
        if (value.compareTo(min) < 0 || value.compareTo(max) > 0) {
            throw new IllegalArgumentException(label + "超出合理范围");
        }
        return value.stripTrailingZeros();
    }

    private DeviceMetricVO fromRecord(HealthRecordVO record) {
        return metric(
                record.type(),
                metricLabel(record.type()),
                record.value(),
                record.systolic(),
                record.diastolic(),
                record.unit(),
                record.status()
        );
    }

    private DeviceMetricVO metric(String type, String label, BigDecimal value, Integer systolic,
                                  Integer diastolic, String unit, String status) {
        return new DeviceMetricVO(type, label, value, systolic, diastolic, unit, status);
    }

    private DeviceRecordWriteResult writeMetrics(Long userId, List<DeviceMetricVO> metrics, LocalDateTime recordedAt) {
        return writeMetrics(userId, metrics, recordedAt, "模拟设备同步");
    }

    private DeviceRecordWriteResult writeMetrics(Long userId, List<DeviceMetricVO> metrics,
                                                 LocalDateTime recordedAt, String remark) {
        List<Long> recordIds = new ArrayList<>();
        List<String> recordTypes = new ArrayList<>();
        DeviceRiskAlertVO riskAlert = null;
        for (DeviceMetricVO metric : metrics) {
            HealthRecordVO record = healthService.createRecord(new HealthRecordCreateDTO(
                    metric.type(),
                    metric.value(),
                    metric.value(),
                    null,
                    metric.systolic(),
                    metric.diastolic(),
                    metric.unit(),
                    recordedAt,
                    "device",
                    remark,
                    null
            ));
            if (record.id() != null) {
                recordIds.add(record.id());
                recordTypes.add(record.type());
                RiskAssessment assessment = riskEngineService.assess(userId, record.id());
                DeviceRiskAlertVO nextAlert = toRiskAlert(record, assessment, recordedAt);
                if (shouldReplaceAlert(riskAlert, nextAlert)) {
                    riskAlert = nextAlert;
                }
            }
        }
        return new DeviceRecordWriteResult(recordIds, recordTypes, riskAlert);
    }

    private DeviceSyncVO toVO(DeviceBind device, List<DeviceMetricVO> metrics, DeviceSignalVO signal) {
        return toVO(device, metrics, signal, new DeviceRecordWriteResult(List.of(), List.of(), null));
    }

    private DeviceSyncVO toVO(DeviceBind device, List<DeviceMetricVO> metrics, DeviceSignalVO signal,
                              DeviceRecordWriteResult writtenRecords) {
        DeviceRecordWriteResult safeWrittenRecords = writtenRecords == null
                ? new DeviceRecordWriteResult(List.of(), List.of(), null)
                : writtenRecords;
        return new DeviceSyncVO(
                device.getId(),
                device.getDeviceName(),
                device.getDeviceType(),
                device.getProvider(),
                device.getBindStatus(),
                device.getLastSyncAt(),
                76,
                "online",
                metrics,
                signal,
                safeWrittenRecords.ids(),
                safeWrittenRecords.types(),
                safeWrittenRecords.riskAlert()
        );
    }

    private DeviceRiskAlertVO toRiskAlert(HealthRecordVO record, RiskAssessment assessment, LocalDateTime occurredAt) {
        return new DeviceRiskAlertVO(
                "device-risk-" + record.id(),
                "DeviceSyncRiskAssessment",
                record.id(),
                "completed",
                assessment.level(),
                assessment.score(),
                assessment.summary(),
                assessment.reasons(),
                null,
                occurredAt,
                LocalDateTime.now(),
                List.of()
        );
    }

    private boolean shouldReplaceAlert(DeviceRiskAlertVO current, DeviceRiskAlertVO candidate) {
        if (candidate == null || !requiresAttention(candidate.riskLevel())) {
            return false;
        }
        if (current == null) {
            return true;
        }
        int candidateRank = riskRank(candidate.riskLevel());
        int currentRank = riskRank(current.riskLevel());
        return candidateRank > currentRank
                || candidateRank == currentRank
                && safeScore(candidate.riskScore()) > safeScore(current.riskScore());
    }

    private boolean requiresAttention(String riskLevel) {
        return "elevated".equals(riskLevel) || "high".equals(riskLevel);
    }

    private int riskRank(String riskLevel) {
        return "high".equals(riskLevel) ? 2 : "elevated".equals(riskLevel) ? 1 : 0;
    }

    private int safeScore(Integer score) {
        return score == null ? 0 : score;
    }

    private record DeviceRecordWriteResult(List<Long> ids, List<String> types, DeviceRiskAlertVO riskAlert) {
    }

    private String normalizeSignalType(String signalType) {
        if (signalType == null || signalType.isBlank()) {
            return "ping";
        }
        String normalized = signalType.trim().toLowerCase(Locale.ROOT);
        return switch (normalized) {
            case "ping", "locate", "vibrate", "sync" -> normalized;
            default -> "custom";
        };
    }

    private String signalMessage(String signalType) {
        return switch (signalType) {
            case "locate" -> "定位请求信号已发送到模拟设备";
            case "vibrate" -> "震动提醒信号已发送到模拟设备";
            case "sync" -> "同步唤醒信号已发送到模拟设备";
            case "custom" -> "自定义信号已发送到模拟设备";
            default -> "在线探测信号已发送到模拟设备";
        };
    }

    private String newSignalId() {
        return "mock-signal-" + UUID.randomUUID().toString().substring(0, 8);
    }

    private String metricLabel(String type) {
        return switch (type) {
            case "heart_rate" -> "心率";
            case "blood_pressure" -> "血压";
            case "blood_glucose" -> "血糖";
            case "steps" -> "步数";
            case "sleep_hours" -> "睡眠";
            default -> "指标";
        };
    }
}

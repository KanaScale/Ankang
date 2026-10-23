package com.ankang.assistant.health.service;

import com.ankang.assistant.config.RedisCacheSupport;
import com.ankang.assistant.config.SecurityUtils;
import com.ankang.assistant.eventmesh.event.HealthRecordCreatedEvent;
import com.ankang.assistant.health.dto.HealthRecordCreateDTO;
import com.ankang.assistant.health.entity.HealthRecord;
import com.ankang.assistant.health.mapper.HealthRecordMapper;
import com.ankang.assistant.health.vo.HealthRecordVO;
import com.ankang.assistant.health.vo.HealthSummaryVO;
import com.ankang.assistant.health.vo.HealthTrendVO;
import com.ankang.assistant.health.vo.PageVO;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.LongSupplier;

@Service
public class HealthService {

    private static final int MAX_PAGE_SIZE = 100;
    private static final int MAX_TREND_DAYS = 365;
    private static final int MAX_RECENT_RECORDS = 20;
    private static final int SUMMARY_LOOKBACK_RECORDS = 50;
    private static final Duration TREND_CACHE_TTL = Duration.ofMinutes(5);
    private static final List<String> SUPPORTED_TYPES = List.of(
            "blood_pressure", "blood_glucose", "heart_rate", "weight", "steps", "sleep_hours", "other"
    );

    private final HealthRecordMapper healthRecordMapper;
    private final ApplicationEventPublisher eventPublisher;
    private final LongSupplier currentUserIdSupplier;
    private final RedisCacheSupport redisCache;

    @Autowired
    public HealthService(HealthRecordMapper healthRecordMapper,
                         ApplicationEventPublisher eventPublisher,
                         RedisCacheSupport redisCache) {
        this(healthRecordMapper, eventPublisher, SecurityUtils::currentUserId, redisCache);
    }

    HealthService(HealthRecordMapper healthRecordMapper) {
        this(healthRecordMapper, event -> { }, () -> 1L, null);
    }

    HealthService(HealthRecordMapper healthRecordMapper, ApplicationEventPublisher eventPublisher,
                  LongSupplier currentUserIdSupplier) {
        this(healthRecordMapper, eventPublisher, currentUserIdSupplier, null);
    }

    HealthService(HealthRecordMapper healthRecordMapper, ApplicationEventPublisher eventPublisher,
                  LongSupplier currentUserIdSupplier, RedisCacheSupport redisCache) {
        this.healthRecordMapper = healthRecordMapper;
        this.eventPublisher = eventPublisher;
        this.currentUserIdSupplier = currentUserIdSupplier;
        this.redisCache = redisCache;
    }

    public PageVO<HealthRecordVO> getRecords(String type, LocalDate startDate, LocalDate endDate,
                                              int page, int size) {
        return getRecordsByUserId(currentUserIdSupplier.getAsLong(), type, startDate, endDate, page, size);
    }

    public PageVO<HealthRecordVO> getRecordsByUserId(Long userId, String type, LocalDate startDate, LocalDate endDate,
                                                     int page, int size) {
        assertValidUserId(userId);
        validateDateRange(startDate, endDate);
        int safePage = Math.max(page, 1);
        int safeSize = Math.min(Math.max(size, 1), MAX_PAGE_SIZE);
        String normalizedType = type == null || type.isBlank() ? null : normalizeType(type);

        LambdaQueryWrapper<HealthRecord> query = new LambdaQueryWrapper<HealthRecord>()
                .eq(HealthRecord::getUserId, userId)
                .eq(normalizedType != null, HealthRecord::getType, normalizedType)
                .ge(startDate != null, HealthRecord::getRecordedAt,
                        startDate == null ? null : startDate.atStartOfDay())
                .lt(endDate != null, HealthRecord::getRecordedAt,
                        endDate == null ? null : endDate.plusDays(1).atStartOfDay())
                .orderByDesc(HealthRecord::getRecordedAt)
                .orderByDesc(HealthRecord::getId);

        Page<HealthRecord> result = healthRecordMapper.selectPage(new Page<>(safePage, safeSize), query);
        return new PageVO<>(result.getRecords().stream().map(this::toVO).toList(),
                result.getTotal(), safePage, safeSize);
    }

    @Transactional
    public HealthRecordVO createRecord(HealthRecordCreateDTO dto) {
        long userId = currentUserIdSupplier.getAsLong();
        String type = normalizeType(dto.type());
        BigDecimal suppliedValue = firstNonNull(dto.value(), dto.value1());
        Integer systolic = dto.systolic();
        Integer diastolic = dto.diastolic();

        if ("blood_pressure".equals(type)) {
            systolic = firstNonNull(systolic, toInteger(dto.value1(), "value1"));
            diastolic = firstNonNull(diastolic, toInteger(dto.value2(), "value2"));
            validateBloodPressure(systolic, diastolic);
            suppliedValue = BigDecimal.valueOf(systolic);
        } else {
            validateValue(type, suppliedValue);
        }

        HealthRecord record = new HealthRecord();
        record.setUserId(userId);
        record.setType(type);
        record.setValue(suppliedValue);
        record.setValue1("blood_pressure".equals(type) ? BigDecimal.valueOf(systolic) : suppliedValue);
        record.setValue2("blood_pressure".equals(type) ? BigDecimal.valueOf(diastolic) : null);
        record.setSystolic(systolic);
        record.setDiastolic(diastolic);
        record.setUnit(dto.unit() == null || dto.unit().isBlank() ? defaultUnit(type) : dto.unit().trim());
        record.setStatus(evaluateStatus(type, suppliedValue, systolic, diastolic));
        record.setSource(dto.source() == null || dto.source().isBlank() ? "manual" : dto.source().trim());
        record.setRemark(dto.remark() == null ? dto.note() : dto.remark());
        record.setRecordedAt(dto.recordedAt() == null ? LocalDateTime.now() : dto.recordedAt());

        if (healthRecordMapper.insert(record) != 1) {
            throw new IllegalStateException("健康记录保存失败");
        }
        clearHealthDerivedCaches(userId);
        eventPublisher.publishEvent(new HealthRecordCreatedEvent(
                userId, record.getId(), LocalDateTime.now()
        ));
        return toVO(record);
    }

    public HealthRecordVO getRecord(Long id) {
        HealthRecord record = findOwnedRecord(id);
        return toVO(record);
    }

    @Transactional
    public void deleteRecord(Long id) {
        long userId = currentUserIdSupplier.getAsLong();
        findOwnedRecord(id);
        if (healthRecordMapper.deleteById(id) != 1) {
            throw new IllegalStateException("健康记录删除失败");
        }
        clearHealthDerivedCaches(userId);
    }

    public HealthSummaryVO getSummary() {
        return getSummaryByUserId(currentUserIdSupplier.getAsLong());
    }

    public HealthSummaryVO getSummaryByUserId(Long userId) {
        assertValidUserId(userId);
        List<HealthRecord> recentRecords = selectRecentRecords(userId, SUMMARY_LOOKBACK_RECORDS);
        if (recentRecords.isEmpty()) {
            return new HealthSummaryVO(0, "暂无健康记录", List.of());
        }

        Map<String, HealthRecord> latestByType = new LinkedHashMap<>();
        Map<String, HealthRecord> previousByType = new LinkedHashMap<>();
        for (HealthRecord record : recentRecords) {
            if (!latestByType.containsKey(record.getType())) {
                latestByType.put(record.getType(), record);
            } else if (!previousByType.containsKey(record.getType())) {
                previousByType.put(record.getType(), record);
            }
        }

        List<HealthSummaryVO.MetricVO> metrics = SUPPORTED_TYPES.stream()
                .filter(latestByType::containsKey)
                .map(type -> toMetricVO(latestByType.get(type), previousByType.get(type)))
                .toList();
        long dangerCount = metrics.stream().filter(metric -> "danger".equals(metric.status())).count();
        long warningCount = metrics.stream().filter(metric -> "warning".equals(metric.status())).count();
        int score = Math.max(0, 100 - (int) dangerCount * 25 - (int) warningCount * 10);
        String status = dangerCount > 0 ? "存在需要关注的异常指标"
                : warningCount > 0 ? "部分指标偏离正常范围"
                : "整体状态良好";
        return new HealthSummaryVO(score, status, metrics);
    }

    public List<HealthRecordVO> listRecentRecords(int limit) {
        return listRecentRecordsByUserId(currentUserIdSupplier.getAsLong(), limit);
    }

    public List<HealthRecordVO> listRecentRecordsByUserId(Long userId, int limit) {
        assertValidUserId(userId);
        int safeLimit = Math.min(Math.max(limit, 1), MAX_RECENT_RECORDS);
        return selectRecentRecords(userId, safeLimit).stream()
                .map(this::toVO)
                .toList();
    }

    public HealthTrendVO getTrend(String type, Integer days, String range) {
        return getTrendByUserId(currentUserIdSupplier.getAsLong(), type, days, range);
    }

    public HealthTrendVO getTrendByUserId(Long userId, String type, Integer days, String range) {
        assertValidUserId(userId);
        String normalizedType = normalizeType(type);
        int resolvedDays = resolveDays(days, range);
        String resolvedRange = resolvedDays + "d";
        String cacheKey = trendCacheKey(userId, normalizedType, resolvedDays);
        if (redisCache != null) {
            HealthTrendVO cached = redisCache.get(cacheKey, HealthTrendVO.class);
            if (cached != null) {
                return cached;
            }
        }

        LocalDate startDate = LocalDate.now().minusDays(resolvedDays - 1L);

        List<HealthRecord> records = healthRecordMapper.selectList(new LambdaQueryWrapper<HealthRecord>()
                .eq(HealthRecord::getUserId, userId)
                .eq(HealthRecord::getType, normalizedType)
                .ge(HealthRecord::getRecordedAt, startDate.atStartOfDay())
                .lt(HealthRecord::getRecordedAt, LocalDate.now().plusDays(1).atStartOfDay())
                .orderByAsc(HealthRecord::getRecordedAt));

        List<BigDecimal> values = records.stream()
                .map(this::trendValue)
                .filter(value -> value != null)
                .toList();
        Map<LocalDate, List<BigDecimal>> valuesByDay = new LinkedHashMap<>();
        records.forEach(record -> {
            BigDecimal value = trendValue(record);
            if (value != null) {
                valuesByDay.computeIfAbsent(record.getRecordedAt().toLocalDate(), ignored -> new ArrayList<>())
                        .add(value);
            }
        });

        List<HealthTrendVO.PointVO> points = valuesByDay.entrySet().stream()
                .map(entry -> new HealthTrendVO.PointVO(entry.getKey(), average(entry.getValue())))
                .toList();
        BigDecimal avg = values.isEmpty() ? BigDecimal.ZERO : average(values);
        BigDecimal max = values.stream().max(Comparator.naturalOrder()).orElse(BigDecimal.ZERO);
        BigDecimal min = values.stream().min(Comparator.naturalOrder()).orElse(BigDecimal.ZERO);
        int abnormalCount = (int) records.stream().filter(record -> !"normal".equals(record.getStatus())).count();
        HealthTrendVO trend = new HealthTrendVO(normalizedType, resolvedRange, points, avg, max, min, abnormalCount);
        if (redisCache != null) {
            redisCache.set(cacheKey, trend, TREND_CACHE_TTL);
        }
        return trend;
    }

    public LocalDateTime getLastRecordTimeByUserId(Long userId) {
        assertValidUserId(userId);
        HealthRecord record = healthRecordMapper.selectOne(new LambdaQueryWrapper<HealthRecord>()
                .eq(HealthRecord::getUserId, userId)
                .orderByDesc(HealthRecord::getRecordedAt)
                .orderByDesc(HealthRecord::getId)
                .last("limit 1"));
        return record == null ? null : record.getRecordedAt();
    }

    private void clearHealthDerivedCaches(long userId) {
        if (redisCache == null) {
            return;
        }
        redisCache.deleteByPattern("health:trend:user:" + userId + ":*");
        redisCache.deleteByPattern("report:weekly:user:" + userId + ":*");
    }

    private String trendCacheKey(long userId, String type, int days) {
        return "health:trend:user:" + userId + ":type:" + type + ":days:" + days;
    }

    private HealthRecord findOwnedRecord(Long id) {
        if (id == null || id <= 0) {
            throw new IllegalArgumentException("健康记录 ID 不合法");
        }
        HealthRecord record = healthRecordMapper.selectOne(new LambdaQueryWrapper<HealthRecord>()
                .eq(HealthRecord::getId, id)
                .eq(HealthRecord::getUserId, currentUserIdSupplier.getAsLong()));
        if (record == null) {
            throw new IllegalArgumentException("健康记录不存在");
        }
        return record;
    }

    private void assertValidUserId(Long userId) {
        if (userId == null || userId <= 0) {
            throw new IllegalArgumentException("用户 ID 不合法");
        }
    }

    private List<HealthRecord> selectRecentRecords(long userId, int limit) {
        return healthRecordMapper.selectList(new LambdaQueryWrapper<HealthRecord>()
                .eq(HealthRecord::getUserId, userId)
                .orderByDesc(HealthRecord::getRecordedAt)
                .orderByDesc(HealthRecord::getId)
                .last("LIMIT " + limit));
    }

    private HealthRecordVO toVO(HealthRecord record) {
        return new HealthRecordVO(record.getId(), record.getType(), record.getValue(), record.getValue1(),
                record.getValue2(), record.getSystolic(), record.getDiastolic(), record.getUnit(),
                record.getStatus(), record.getSource(), record.getRemark(), record.getRecordedAt());
    }

    private BigDecimal trendValue(HealthRecord record) {
        if ("blood_pressure".equals(record.getType()) && record.getSystolic() != null) {
            return BigDecimal.valueOf(record.getSystolic());
        }
        return firstNonNull(record.getValue(), record.getValue1());
    }

    private HealthSummaryVO.MetricVO toMetricVO(HealthRecord latest, HealthRecord previous) {
        return new HealthSummaryVO.MetricVO(
                latest.getType(),
                typeName(latest.getType()),
                displayValue(latest),
                latest.getUnit(),
                latest.getStatus(),
                trendText(latest, previous)
        );
    }

    private String displayValue(HealthRecord record) {
        if ("blood_pressure".equals(record.getType()) && record.getSystolic() != null && record.getDiastolic() != null) {
            return record.getSystolic() + "/" + record.getDiastolic();
        }
        BigDecimal value = trendValue(record);
        return value == null ? "未记录" : value.stripTrailingZeros().toPlainString();
    }

    private String trendText(HealthRecord latest, HealthRecord previous) {
        if (previous == null) {
            return "新记录";
        }
        BigDecimal latestValue = trendValue(latest);
        BigDecimal previousValue = trendValue(previous);
        if (latestValue == null || previousValue == null) {
            return "0";
        }
        BigDecimal delta = latestValue.subtract(previousValue).setScale(2, RoundingMode.HALF_UP).stripTrailingZeros();
        if (delta.compareTo(BigDecimal.ZERO) > 0) {
            return "+" + delta.toPlainString();
        }
        return delta.toPlainString();
    }

    private String typeName(String type) {
        return switch (type) {
            case "blood_pressure" -> "血压";
            case "blood_glucose" -> "血糖";
            case "heart_rate" -> "心率";
            case "weight" -> "体重";
            case "steps" -> "步数";
            case "sleep_hours" -> "睡眠";
            default -> "其他";
        };
    }

    private int resolveDays(Integer days, String range) {
        int resolved;
        if (days != null) {
            resolved = days;
        } else if (range == null || range.isBlank()) {
            resolved = 7;
        } else if (range.matches("\\d+d")) {
            try {
                resolved = Integer.parseInt(range.substring(0, range.length() - 1));
            } catch (NumberFormatException ex) {
                throw new IllegalArgumentException("range 中的天数过大");
            }
        } else {
            throw new IllegalArgumentException("range 格式应为 7d、30d 等天数格式");
        }
        if (resolved < 1 || resolved > MAX_TREND_DAYS) {
            throw new IllegalArgumentException("趋势天数必须在 1 到 " + MAX_TREND_DAYS + " 之间");
        }
        return resolved;
    }

    private void validateDateRange(LocalDate startDate, LocalDate endDate) {
        if (startDate != null && endDate != null && startDate.isAfter(endDate)) {
            throw new IllegalArgumentException("startDate 不能晚于 endDate");
        }
    }

    private void validateBloodPressure(Integer systolic, Integer diastolic) {
        if (systolic == null || diastolic == null) {
            throw new IllegalArgumentException("血压记录必须同时提供收缩压和舒张压");
        }
        if (systolic < 40 || systolic > 300 || diastolic < 30 || diastolic > 200) {
            throw new IllegalArgumentException("血压数值超出合理录入范围");
        }
        if (systolic <= diastolic) {
            throw new IllegalArgumentException("收缩压必须大于舒张压");
        }
    }

    private void validateValue(String type, BigDecimal value) {
        if (value == null) {
            throw new IllegalArgumentException(type + " 记录必须提供 value");
        }
        if (value.compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("健康指标数值必须大于 0");
        }
    }

    private String normalizeType(String type) {
        String normalized = switch (type == null ? "" : type.trim()) {
            case "bloodSugar", "blood_sugar" -> "blood_glucose";
            case "bloodPressure" -> "blood_pressure";
            case "heartRate" -> "heart_rate";
            case "sleepHours", "sleep" -> "sleep_hours";
            default -> type == null ? "" : type.trim();
        };
        if (!SUPPORTED_TYPES.contains(normalized)) {
            throw new IllegalArgumentException("不支持的健康指标类型: " + type);
        }
        return normalized;
    }

    private String defaultUnit(String type) {
        return switch (type) {
            case "blood_pressure" -> "mmHg";
            case "blood_glucose" -> "mmol/L";
            case "heart_rate" -> "bpm";
            case "weight" -> "kg";
            case "steps" -> "步";
            case "sleep_hours" -> "小时";
            default -> "";
        };
    }

    private String evaluateStatus(String type, BigDecimal value, Integer systolic, Integer diastolic) {
        if ("blood_pressure".equals(type)) {
            if (systolic >= 160 || diastolic >= 100) {
                return "danger";
            }
            if (systolic >= 140 || diastolic >= 90 || systolic < 90 || diastolic < 60) {
                return "warning";
            }
        } else if ("blood_glucose".equals(type)) {
            if (value.compareTo(new BigDecimal("11.1")) >= 0) {
                return "danger";
            }
            if (value.compareTo(new BigDecimal("6.1")) > 0 || value.compareTo(new BigDecimal("3.9")) < 0) {
                return "warning";
            }
        } else if ("heart_rate".equals(type)) {
            if (value.compareTo(new BigDecimal("120")) > 0 || value.compareTo(new BigDecimal("50")) < 0) {
                return "danger";
            }
            if (value.compareTo(new BigDecimal("100")) > 0 || value.compareTo(new BigDecimal("60")) < 0) {
                return "warning";
            }
        }
        return "normal";
    }

    private BigDecimal average(List<BigDecimal> values) {
        return values.stream().reduce(BigDecimal.ZERO, BigDecimal::add)
                .divide(BigDecimal.valueOf(values.size()), 2, RoundingMode.HALF_UP)
                .stripTrailingZeros();
    }

    private BigDecimal firstNonNull(BigDecimal first, BigDecimal second) {
        return first != null ? first : second;
    }

    private Integer firstNonNull(Integer first, Integer second) {
        return first != null ? first : second;
    }

    private Integer toInteger(BigDecimal value, String field) {
        if (value == null) {
            return null;
        }
        try {
            return value.intValueExact();
        } catch (ArithmeticException ex) {
            throw new IllegalArgumentException(field + " 必须是整数");
        }
    }
}

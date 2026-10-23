package com.ankang.assistant.report.service;

import com.ankang.assistant.config.RedisCacheSupport;
import com.ankang.assistant.health.entity.HealthRecord;
import com.ankang.assistant.health.mapper.HealthRecordMapper;
import com.ankang.assistant.report.vo.WeeklyHealthReportVO;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Duration;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
public class ReportService {

    /** TODO: 接入认证模块后，从登录上下文读取当前用户。 */
    private static final long DEMO_USER_ID = 1L;
    private static final Duration WEEKLY_REPORT_CACHE_TTL = Duration.ofMinutes(5);

    private final HealthRecordMapper healthRecordMapper;
    private final RedisCacheSupport redisCache;

    @Autowired
    public ReportService(HealthRecordMapper healthRecordMapper, RedisCacheSupport redisCache) {
        this.healthRecordMapper = healthRecordMapper;
        this.redisCache = redisCache;
    }

    public ReportService(HealthRecordMapper healthRecordMapper) {
        this.healthRecordMapper = healthRecordMapper;
        this.redisCache = null;
    }

    public WeeklyHealthReportVO weeklyReport(LocalDate weekStart) {
        LocalDate start = weekStart == null
                ? LocalDate.now().with(DayOfWeek.MONDAY)
                : weekStart;
        LocalDate end = start.plusDays(6);
        String cacheKey = weeklyReportCacheKey(start);
        if (redisCache != null) {
            WeeklyHealthReportVO cached = redisCache.get(cacheKey, WeeklyHealthReportVO.class);
            if (cached != null) {
                return cached;
            }
        }

        List<HealthRecord> records = healthRecordMapper.selectList(new LambdaQueryWrapper<HealthRecord>()
                .eq(HealthRecord::getUserId, DEMO_USER_ID)
                .ge(HealthRecord::getRecordedAt, start.atStartOfDay())
                .lt(HealthRecord::getRecordedAt, end.plusDays(1).atStartOfDay())
                .orderByAsc(HealthRecord::getRecordedAt));

        Map<String, Object> indicators = new LinkedHashMap<>();
        indicators.put("recordCount", records.size());
        putBloodPressureAverage(indicators, records);
        putAverage(indicators, records, "blood_glucose", "bloodGlucoseAvg");
        putAverage(indicators, records, "heart_rate", "heartRateAvg");
        putAverage(indicators, records, "weight", "weightAvg");
        long abnormalCount = records.stream().filter(record -> !"normal".equals(record.getStatus())).count();
        indicators.put("abnormalCount", abnormalCount);

        String summary;
        if (records.isEmpty()) {
            summary = "本周暂无健康记录，建议保持规律测量。";
        } else if (abnormalCount == 0) {
            summary = "本周已记录 " + records.size() + " 次健康数据，指标整体平稳，请继续保持规律测量。";
        } else {
            summary = "本周已记录 " + records.size() + " 次健康数据，其中 " + abnormalCount
                    + " 次指标需要关注，建议及时复测并在持续异常时咨询专业医生。";
        }
        WeeklyHealthReportVO report = new WeeklyHealthReportVO(start.toString(), end.toString(), summary, indicators);
        if (redisCache != null) {
            redisCache.set(cacheKey, report, WEEKLY_REPORT_CACHE_TTL);
        }
        return report;
    }

    private String weeklyReportCacheKey(LocalDate start) {
        return "report:weekly:user:" + DEMO_USER_ID + ":start:" + start;
    }

    private void putBloodPressureAverage(Map<String, Object> indicators, List<HealthRecord> records) {
        List<BigDecimal> systolic = records.stream()
                .filter(record -> "blood_pressure".equals(record.getType()) && record.getSystolic() != null)
                .map(record -> BigDecimal.valueOf(record.getSystolic()))
                .toList();
        List<BigDecimal> diastolic = records.stream()
                .filter(record -> "blood_pressure".equals(record.getType()) && record.getDiastolic() != null)
                .map(record -> BigDecimal.valueOf(record.getDiastolic()))
                .toList();
        if (!systolic.isEmpty() && !diastolic.isEmpty()) {
            indicators.put("bloodPressureAvg", average(systolic).setScale(0, RoundingMode.HALF_UP)
                    + "/" + average(diastolic).setScale(0, RoundingMode.HALF_UP));
        }
    }

    private void putAverage(Map<String, Object> indicators, List<HealthRecord> records,
                            String type, String resultKey) {
        List<BigDecimal> values = records.stream()
                .filter(record -> type.equals(record.getType()))
                .map(record -> record.getValue() == null ? record.getValue1() : record.getValue())
                .filter(value -> value != null)
                .toList();
        if (!values.isEmpty()) {
            indicators.put(resultKey, average(values));
        }
    }

    private BigDecimal average(List<BigDecimal> values) {
        return values.stream().reduce(BigDecimal.ZERO, BigDecimal::add)
                .divide(BigDecimal.valueOf(values.size()), 2, RoundingMode.HALF_UP)
                .stripTrailingZeros();
    }
}

package com.ankang.assistant.health.service;

import com.ankang.assistant.config.RedisCacheSupport;
import com.ankang.assistant.eventmesh.event.HealthRecordCreatedEvent;
import com.ankang.assistant.health.dto.HealthRecordCreateDTO;
import com.ankang.assistant.health.entity.HealthRecord;
import com.ankang.assistant.health.mapper.HealthRecordMapper;
import com.ankang.assistant.health.vo.HealthRecordVO;
import com.ankang.assistant.health.vo.HealthSummaryVO;
import com.ankang.assistant.health.vo.HealthTrendVO;
import com.baomidou.mybatisplus.core.MybatisConfiguration;
import com.baomidou.mybatisplus.core.conditions.Wrapper;
import com.baomidou.mybatisplus.core.metadata.TableInfoHelper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import org.apache.ibatis.builder.MapperBuilderAssistant;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class HealthServiceTest {

    @Mock
    private HealthRecordMapper healthRecordMapper;
    @Mock
    private ApplicationEventPublisher eventPublisher;
    @Mock
    private RedisCacheSupport redisCache;

    private HealthService healthService;

    @BeforeEach
    void setUp() {
        TableInfoHelper.initTableInfo(
                new MapperBuilderAssistant(new MybatisConfiguration(), ""), HealthRecord.class
        );
        healthService = new HealthService(healthRecordMapper, event -> { }, () -> 42L);
    }

    @Test
    void createsBloodPressureRecordWithCompatibleFieldsAndStatus() {
        when(healthRecordMapper.insert(any(HealthRecord.class))).thenAnswer(invocation -> {
            HealthRecord record = invocation.getArgument(0);
            record.setId(88L);
            return 1;
        });
        HealthRecordCreateDTO dto = new HealthRecordCreateDTO(
                "bloodPressure", null, new BigDecimal("145"), new BigDecimal("92"),
                null, null, null, null, null, "晚间测量", null
        );

        HealthRecordVO result = healthService.createRecord(dto);

        assertThat(result.id()).isEqualTo(88L);
        assertThat(result.type()).isEqualTo("blood_pressure");
        assertThat(result.value()).isEqualByComparingTo("145");
        assertThat(result.value1()).isEqualByComparingTo("145");
        assertThat(result.value2()).isEqualByComparingTo("92");
        assertThat(result.systolic()).isEqualTo(145);
        assertThat(result.diastolic()).isEqualTo(92);
        assertThat(result.unit()).isEqualTo("mmHg");
        assertThat(result.status()).isEqualTo("warning");
        assertThat(result.source()).isEqualTo("manual");
        verify(healthRecordMapper).insert(argThat((HealthRecord record) -> record.getUserId().equals(42L)));
    }

    @Test
    void rejectsIncompleteBloodPressureRecord() {
        HealthRecordCreateDTO dto = new HealthRecordCreateDTO(
                "blood_pressure", null, null, null, 120, null,
                null, null, null, null, null
        );

        assertThatThrownBy(() -> healthService.createRecord(dto))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("收缩压和舒张压");
        verify(healthRecordMapper, never()).insert(any(HealthRecord.class));
    }

    @Test
    void calculatesTrendFromPersistedRecords() {
        LocalDateTime now = LocalDateTime.now();
        when(healthRecordMapper.selectList(any(Wrapper.class))).thenReturn(List.of(
                record(1L, "blood_glucose", "5.0", "normal", now.minusDays(1)),
                record(2L, "blood_glucose", "7.0", "warning", now)
        ));

        HealthTrendVO trend = healthService.getTrend("bloodSugar", null, "7d");

        assertThat(trend.type()).isEqualTo("blood_glucose");
        assertThat(trend.range()).isEqualTo("7d");
        assertThat(trend.avg()).isEqualByComparingTo("6");
        assertThat(trend.min()).isEqualByComparingTo("5");
        assertThat(trend.max()).isEqualByComparingTo("7");
        assertThat(trend.abnormalCount()).isEqualTo(1);
        assertThat(trend.points()).hasSize(2);
    }

    @Test
    void rejectsInvalidTrendRange() {
        assertThatThrownBy(() -> healthService.getTrend("heart_rate", null, "all"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("range");
        verify(healthRecordMapper, never()).selectList(any(Wrapper.class));
    }

    @Test
    void statusMatchesTheRangesShownByTheClient() {
        when(healthRecordMapper.insert(any(HealthRecord.class))).thenAnswer(invocation -> {
            HealthRecord record = invocation.getArgument(0);
            record.setId(90L);
            return 1;
        });

        HealthRecordVO lowHeartRate = healthService.createRecord(new HealthRecordCreateDTO(
                "heartRate", new BigDecimal("50"), null, null, null, null,
                null, null, null, null, null
        ));
        HealthRecordVO aboveFastingGlucoseRange = healthService.createRecord(new HealthRecordCreateDTO(
                "bloodSugar", new BigDecimal("6.2"), null, null, null, null,
                null, null, null, null, null
        ));

        assertThat(lowHeartRate.status()).isEqualTo("warning");
        assertThat(aboveFastingGlucoseRange.status()).isEqualTo("warning");
    }

    @Test
    void paginatesFiltersAndValidatesDateRangesAndUsers() {
        when(healthRecordMapper.selectPage(any(Page.class), any())).thenAnswer(invocation -> {
            Page<HealthRecord> page = invocation.getArgument(0);
            page.setRecords(List.of(record(1L, "weight", "60", "normal", LocalDateTime.now())));
            page.setTotal(1);
            return page;
        });

        var page = healthService.getRecords(
                "weight", LocalDate.now().minusDays(1), LocalDate.now(), 0, 1000
        );
        assertThat(page.page()).isEqualTo(1);
        assertThat(page.pageSize()).isEqualTo(100);
        assertThat(page.items()).hasSize(1);

        assertThatThrownBy(() -> healthService.getRecordsByUserId(
                null, null, null, null, 1, 10
        )).hasMessageContaining("用户 ID");
        assertThatThrownBy(() -> healthService.getRecords(
                null, LocalDate.now(), LocalDate.now().minusDays(1), 1, 10
        )).hasMessageContaining("startDate");
    }

    @Test
    void createsAllMetricKindsClearsCachesPublishesEventsAndHandlesInsertFailure() {
        HealthService cachedService = new HealthService(
                healthRecordMapper, eventPublisher, () -> 42L, redisCache
        );
        when(healthRecordMapper.insert(any(HealthRecord.class))).thenAnswer(invocation -> {
            HealthRecord healthRecord = invocation.getArgument(0);
            healthRecord.setId(100L);
            return 1;
        });

        List<HealthRecordVO> records = List.of(
                cachedService.createRecord(dto("blood_pressure", null, 170, 105)),
                cachedService.createRecord(dto("blood_glucose", "12", null, null)),
                cachedService.createRecord(dto("heart_rate", "110", null, null)),
                cachedService.createRecord(dto("weight", "65", null, null)),
                cachedService.createRecord(dto("steps", "8000", null, null)),
                cachedService.createRecord(dto("sleep_hours", "7", null, null)),
                cachedService.createRecord(dto("other", "1", null, null))
        );
        assertThat(records).extracting(HealthRecordVO::unit)
                .contains("mmHg", "mmol/L", "bpm", "kg", "步", "小时", "");
        assertThat(records.get(0).status()).isEqualTo("danger");
        assertThat(records.get(1).status()).isEqualTo("danger");
        assertThat(records.get(2).status()).isEqualTo("warning");
        verify(redisCache, times(14)).deleteByPattern(any());
        verify(eventPublisher, times(7)).publishEvent(any(HealthRecordCreatedEvent.class));

        when(healthRecordMapper.insert(any(HealthRecord.class))).thenReturn(0);
        assertThatThrownBy(() -> cachedService.createRecord(dto("weight", "60", null, null)))
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    void getsDeletesAndValidatesOwnedRecords() {
        HealthRecord owned = record(8L, "weight", "60", "normal", LocalDateTime.now());
        when(healthRecordMapper.selectOne(any())).thenReturn(owned);
        assertThat(healthService.getRecord(8L).id()).isEqualTo(8L);

        when(healthRecordMapper.deleteById(8L)).thenReturn(1);
        healthService.deleteRecord(8L);

        when(healthRecordMapper.deleteById(8L)).thenReturn(0);
        assertThatThrownBy(() -> healthService.deleteRecord(8L))
                .isInstanceOf(IllegalStateException.class);
        assertThatThrownBy(() -> healthService.getRecord(0L)).hasMessageContaining("ID");

        when(healthRecordMapper.selectOne(any())).thenReturn(null);
        assertThatThrownBy(() -> healthService.getRecord(8L)).hasMessageContaining("不存在");
    }

    @Test
    void summarizesRecentMetricsAndTrendDirections() {
        LocalDateTime now = LocalDateTime.now();
        HealthRecord latestPressure = pressure(1L, 170, 105, "danger", now);
        HealthRecord previousPressure = pressure(2L, 140, 90, "warning", now.minusDays(1));
        HealthRecord latestWeight = record(3L, "weight", "60", "normal", now);
        HealthRecord previousWeight = record(4L, "weight", "61", "normal", now.minusDays(1));
        HealthRecord empty = record(5L, "other", "1", "normal", now);
        empty.setValue(null);
        empty.setValue1(null);
        when(healthRecordMapper.selectList(any())).thenReturn(List.of(
                latestPressure, previousPressure, latestWeight, previousWeight, empty
        ));

        HealthSummaryVO summary = healthService.getSummary();
        assertThat(summary.healthScore()).isEqualTo(75);
        assertThat(summary.status()).contains("异常");
        assertThat(summary.metrics()).extracting(HealthSummaryVO.MetricVO::trend)
                .contains("+30", "-1", "新记录");

        when(healthRecordMapper.selectList(any())).thenReturn(List.of());
        assertThat(healthService.getSummaryByUserId(42L).healthScore()).isZero();
        assertThat(healthService.listRecentRecords(0)).isEmpty();
    }

    @Test
    void usesTrendCacheWritesMissesAndReturnsLastRecordTime() {
        HealthService cachedService = new HealthService(
                healthRecordMapper, eventPublisher, () -> 42L, redisCache
        );
        HealthTrendVO cached = new HealthTrendVO(
                "weight", "7d", List.of(), BigDecimal.ONE, BigDecimal.ONE, BigDecimal.ONE, 0
        );
        when(redisCache.get(any(), eq(HealthTrendVO.class))).thenReturn(cached);
        assertThat(cachedService.getTrend("weight", 7, null)).isSameAs(cached);

        when(redisCache.get(any(), eq(HealthTrendVO.class))).thenReturn(null);
        when(healthRecordMapper.selectList(any())).thenReturn(List.of(
                record(1L, "weight", "60", "normal", LocalDateTime.now())
        ));
        assertThat(cachedService.getTrendByUserId(42L, "weight", null, null).range()).isEqualTo("7d");
        verify(redisCache).set(any(), any(HealthTrendVO.class), any());

        HealthRecord last = record(9L, "weight", "60", "normal", LocalDateTime.now());
        when(healthRecordMapper.selectOne(any())).thenReturn(last, null);
        assertThat(cachedService.getLastRecordTimeByUserId(42L)).isEqualTo(last.getRecordedAt());
        assertThat(cachedService.getLastRecordTimeByUserId(42L)).isNull();
    }

    @Test
    void coversNormalizationRangesUnitsStatusesAndNumericValidationBranches() {
        for (String alias : List.of(
                "bloodSugar", "blood_sugar", "bloodPressure", "heartRate", "sleepHours", "sleep"
        )) {
            assertThat((String) ReflectionTestUtils.invokeMethod(healthService, "normalizeType", alias))
                    .isNotBlank();
        }
        assertThatThrownBy(() -> ReflectionTestUtils.invokeMethod(healthService, "normalizeType", "bad"))
                .isInstanceOf(IllegalArgumentException.class);

        for (String type : List.of(
                "blood_pressure", "blood_glucose", "heart_rate", "weight", "steps", "sleep_hours", "other"
        )) {
            assertThat((String) ReflectionTestUtils.invokeMethod(healthService, "defaultUnit", type)).isNotNull();
            assertThat((String) ReflectionTestUtils.invokeMethod(healthService, "typeName", type)).isNotNull();
        }

        assertThat((int) ReflectionTestUtils.invokeMethod(healthService, "resolveDays", null, "30d"))
                .isEqualTo(30);
        assertThatThrownBy(() -> ReflectionTestUtils.invokeMethod(healthService, "resolveDays", 0, null))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> ReflectionTestUtils.invokeMethod(healthService, "resolveDays", null, "x"))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> ReflectionTestUtils.invokeMethod(
                healthService, "toInteger", new BigDecimal("1.5"), "value"))
                .isInstanceOf(IllegalArgumentException.class);

        assertThatThrownBy(() -> healthService.createRecord(dto("weight", "0", null, null)))
                .hasMessageContaining("大于 0");
        assertThatThrownBy(() -> healthService.createRecord(dto("blood_pressure", null, 80, 90)))
                .hasMessageContaining("收缩压");
        assertThatThrownBy(() -> healthService.createRecord(dto("blood_pressure", null, 400, 90)))
                .hasMessageContaining("范围");
    }

    private HealthRecordCreateDTO dto(String type, String value, Integer systolic, Integer diastolic) {
        BigDecimal number = value == null ? null : new BigDecimal(value);
        return new HealthRecordCreateDTO(
                type, number, number, null, systolic, diastolic,
                null, null, null, null, "note"
        );
    }

    private HealthRecord pressure(Long id, int systolic, int diastolic,
                                  String status, LocalDateTime recordedAt) {
        HealthRecord record = record(id, "blood_pressure", Integer.toString(systolic), status, recordedAt);
        record.setSystolic(systolic);
        record.setDiastolic(diastolic);
        record.setUnit("mmHg");
        return record;
    }

    private HealthRecord record(Long id, String type, String value, String status, LocalDateTime recordedAt) {
        HealthRecord record = new HealthRecord();
        record.setId(id);
        record.setUserId(42L);
        record.setType(type);
        record.setValue(new BigDecimal(value));
        record.setValue1(new BigDecimal(value));
        record.setUnit("mmol/L");
        record.setStatus(status);
        record.setSource("manual");
        record.setRecordedAt(recordedAt);
        return record;
    }

}

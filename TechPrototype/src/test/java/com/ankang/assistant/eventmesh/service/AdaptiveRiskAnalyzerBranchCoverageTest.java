package com.ankang.assistant.eventmesh.service;

import com.ankang.assistant.health.entity.HealthRecord;
import org.junit.jupiter.api.Test;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class AdaptiveRiskAnalyzerBranchCoverageTest {

    private final AdaptiveRiskAnalyzer analyzer = new AdaptiveRiskAnalyzer();

    @Test
    void coversSourceConfidenceLabelsIdentityAndValueFallbacks() {
        for (String source : List.of(
                "health_connect", "medical_device", "smart_band", "wearable",
                "device", "watch", "manual", "custom"
        )) {
            HealthRecord current = metric(1L, "heart_rate", "72", source, LocalDateTime.now());
            Double confidence = invoke(
                    "dataConfidence",
                    new Class<?>[]{HealthRecord.class, List.class},
                    current,
                    List.of(current)
            );
            String label = invoke(
                    "sourceLabel",
                    new Class<?>[]{HealthRecord.class},
                    current
            );
            assertThat(confidence).isBetween(0.60, 1.0);
            assertThat(label).isNotBlank();
        }

        List<HealthRecord> manySamples = new ArrayList<>();
        for (int i = 0; i < 50; i++) {
            manySamples.add(metric((long) i, "heart_rate", "72", "health_connect",
                    LocalDateTime.now().minusMinutes(i)));
        }
        Double saturatedConfidence = invoke(
                "dataConfidence",
                new Class<?>[]{HealthRecord.class, List.class},
                manySamples.get(0),
                manySamples
        );
        assertThat(saturatedConfidence).isEqualTo(0.98);

        HealthRecord nullSource = metric(60L, "heart_rate", "72", null, LocalDateTime.now());
        assertThat((String) invoke("normalizedSource", new Class<?>[]{HealthRecord.class}, (Object) null))
                .isEmpty();
        assertThat((String) invoke("normalizedSource", new Class<?>[]{HealthRecord.class}, nullSource))
                .isEmpty();
        nullSource.setSource(" Manual ");
        assertThat((String) invoke("normalizedSource", new Class<?>[]{HealthRecord.class}, nullSource))
                .isEqualTo("manual");

        HealthRecord sameIdLeft = metric(70L, "heart_rate", "72", "manual", LocalDateTime.now());
        HealthRecord sameIdRight = metric(70L, "heart_rate", "73", "manual", LocalDateTime.now());
        HealthRecord differentId = metric(71L, "heart_rate", "72", "manual", LocalDateTime.now());
        assertThat((Boolean) invoke(
                "sameRecord", new Class<?>[]{HealthRecord.class, HealthRecord.class},
                null, sameIdRight)).isFalse();
        assertThat((Boolean) invoke(
                "sameRecord", new Class<?>[]{HealthRecord.class, HealthRecord.class},
                sameIdLeft, null)).isFalse();
        assertThat((Boolean) invoke(
                "sameRecord", new Class<?>[]{HealthRecord.class, HealthRecord.class},
                sameIdLeft, sameIdRight)).isTrue();
        assertThat((Boolean) invoke(
                "sameRecord", new Class<?>[]{HealthRecord.class, HealthRecord.class},
                sameIdLeft, differentId)).isFalse();
        sameIdLeft.setId(null);
        assertThat((Boolean) invoke(
                "sameRecord", new Class<?>[]{HealthRecord.class, HealthRecord.class},
                sameIdLeft, sameIdLeft)).isTrue();

        HealthRecord value1Only = metric(80L, "heart_rate", "72", "manual", LocalDateTime.now());
        value1Only.setValue1(value1Only.getValue());
        value1Only.setValue(null);
        assertThat((BigDecimal) invoke("valueOf", new Class<?>[]{HealthRecord.class}, value1Only))
                .isEqualByComparingTo("72");
        assertThat((BigDecimal) invoke("valueOf", new Class<?>[]{HealthRecord.class}, (Object) null))
                .isNull();
    }

    @Test
    void coversTimeScaleMedianAndChiSquareDecisionTables() {
        assertThat((Integer) invoke("timeBucket", new Class<?>[]{LocalDateTime.class}, atHour(5))).isZero();
        assertThat((Integer) invoke("timeBucket", new Class<?>[]{LocalDateTime.class}, atHour(11))).isZero();
        assertThat((Integer) invoke("timeBucket", new Class<?>[]{LocalDateTime.class}, atHour(12))).isEqualTo(1);
        assertThat((Integer) invoke("timeBucket", new Class<?>[]{LocalDateTime.class}, atHour(17))).isEqualTo(1);
        assertThat((Integer) invoke("timeBucket", new Class<?>[]{LocalDateTime.class}, atHour(18))).isEqualTo(2);
        assertThat((Integer) invoke("timeBucket", new Class<?>[]{LocalDateTime.class}, atHour(22))).isEqualTo(2);
        assertThat((Integer) invoke("timeBucket", new Class<?>[]{LocalDateTime.class}, atHour(23))).isEqualTo(3);
        assertThat((Integer) invoke("timeBucket", new Class<?>[]{LocalDateTime.class}, atHour(4))).isEqualTo(3);

        assertThat((Double) invoke("minimumScale", new Class<?>[]{String.class}, "systolic")).isEqualTo(5.0);
        assertThat((Double) invoke("minimumScale", new Class<?>[]{String.class}, "diastolic")).isEqualTo(4.0);
        assertThat((Double) invoke("minimumScale", new Class<?>[]{String.class}, "heart_rate")).isEqualTo(3.0);
        assertThat((Double) invoke("minimumScale", new Class<?>[]{String.class}, "blood_glucose")).isEqualTo(0.30);
        assertThat((Double) invoke("minimumScale", new Class<?>[]{String.class}, "weight")).isEqualTo(0.50);
        assertThat((Double) invoke("minimumScale", new Class<?>[]{String.class}, "other")).isEqualTo(1.0);

        assertThat((Double) invoke("median", new Class<?>[]{double[].class}, (Object) new double[]{}))
                .isZero();
        assertThat((Double) invoke("median", new Class<?>[]{double[].class}, (Object) new double[]{3, 1, 2}))
                .isEqualTo(2.0);
        assertThat((Double) invoke("median", new Class<?>[]{double[].class}, (Object) new double[]{4, 1, 3, 2}))
                .isEqualTo(2.5);

        assertThat((Double) invoke("chiSquareThreshold95", new Class<?>[]{int.class}, 2)).isEqualTo(5.99);
        assertThat((Double) invoke("chiSquareThreshold95", new Class<?>[]{int.class}, 3)).isEqualTo(7.81);
        assertThat((Double) invoke("chiSquareThreshold95", new Class<?>[]{int.class}, 4)).isEqualTo(9.49);
        assertThat((Double) invoke("chiSquareThreshold99", new Class<?>[]{int.class}, 2)).isEqualTo(9.21);
        assertThat((Double) invoke("chiSquareThreshold99", new Class<?>[]{int.class}, 3)).isEqualTo(11.34);
        assertThat((Double) invoke("chiSquareThreshold99", new Class<?>[]{int.class}, 4)).isEqualTo(13.28);
    }

    @Test
    void coversFeatureExtractionMatrixPivotAndQuadraticFallbacks() {
        HealthRecord pressure = metric(100L, "blood_pressure", "120", "device", LocalDateTime.now());
        pressure.setSystolic(120);
        pressure.setDiastolic(null);
        assertThat((List<?>) invoke("featuresOf", new Class<?>[]{HealthRecord.class}, pressure)).hasSize(1);
        pressure.setSystolic(null);
        pressure.setDiastolic(80);
        assertThat((List<?>) invoke("featuresOf", new Class<?>[]{HealthRecord.class}, pressure)).hasSize(1);
        pressure.setSystolic(120);
        assertThat((List<?>) invoke("featuresOf", new Class<?>[]{HealthRecord.class}, pressure)).hasSize(2);

        for (String type : List.of("heart_rate", "blood_glucose", "weight")) {
            HealthRecord record = metric(101L, type, "10", "device", LocalDateTime.now());
            assertThat((List<?>) invoke("featuresOf", new Class<?>[]{HealthRecord.class}, record)).hasSize(1);
        }
        HealthRecord noValue = metric(102L, "weight", "10", "device", LocalDateTime.now());
        noValue.setValue(null);
        assertThat((List<?>) invoke("featuresOf", new Class<?>[]{HealthRecord.class}, noValue)).isEmpty();

        assertThat((Object) invoke(
                "featureValue", new Class<?>[]{HealthRecord.class, String.class},
                null, "heart_rate")).isNull();
        HealthRecord noTime = metric(103L, "heart_rate", "72", "device", null);
        assertThat((Object) invoke(
                "featureValue", new Class<?>[]{HealthRecord.class, String.class},
                noTime, "heart_rate")).isNull();
        HealthRecord heart = metric(104L, "heart_rate", "72", "device", LocalDateTime.now());
        assertThat((Object) invoke(
                "featureValue", new Class<?>[]{HealthRecord.class, String.class},
                heart, "heart_rate")).isNotNull();
        assertThat((Object) invoke(
                "featureValue", new Class<?>[]{HealthRecord.class, String.class},
                heart, "blood_glucose")).isNull();
        assertThat((Object) invoke(
                "featureValue", new Class<?>[]{HealthRecord.class, String.class},
                heart, "unknown")).isNull();

        double[][] identity = invoke(
                "invert", new Class<?>[]{double[][].class},
                (Object) new double[][]{{1, 0}, {0, 1}}
        );
        assertThat(identity).isDeepEqualTo(new double[][]{{1, 0}, {0, 1}});
        double[][] swappedPivot = invoke(
                "invert", new Class<?>[]{double[][].class},
                (Object) new double[][]{{0, 1}, {1, 0}}
        );
        assertThat(swappedPivot).isNotNull();
        assertThat((double[][]) invoke(
                "invert", new Class<?>[]{double[][].class},
                (Object) new double[][]{{0, 0}, {0, 0}}
        )).isNull();

        double[][] covariance = invoke(
                "shrunkCovariance", new Class<?>[]{List.class, int.class},
                List.of(new double[]{1, 2}, new double[]{2, 4}),
                2
        );
        assertThat(covariance).hasDimensions(2, 2);
        assertThat((Double) invoke(
                "quadraticForm", new Class<?>[]{double[].class, double[][].class},
                new double[]{1, 2}, new double[][]{{1, 0}, {0, 1}}
        )).isEqualTo(5.0);
        assertThat((Double) invoke(
                "quadraticForm", new Class<?>[]{double[].class, double[][].class},
                new double[]{1}, new double[][]{{-1}}
        )).isZero();
    }

    @Test
    void coversRemainingGuardsHistoricalReplacementAndDiagonalFallback() {
        HealthRecord valid = metric(200L, "heart_rate", "72", "device", LocalDateTime.now());
        assertThat(analyzer.analyze(valid, null, List.of(valid)).score()).isZero();
        assertThat(analyzer.analyze(valid, Map.of(), List.of(valid)).score()).isZero();

        assertThat((Object) invoke(
                "analyzeRecord",
                new Class<?>[]{HealthRecord.class, List.class},
                null,
                List.of(valid)
        )).isNotNull();

        HealthRecord nullType = metric(201L, "heart_rate", "72", "device", LocalDateTime.now());
        nullType.setType(null);
        assertThat((Object) invoke(
                "analyzeRecord",
                new Class<?>[]{HealthRecord.class, List.class},
                nullType,
                List.of(nullType)
        )).isNotNull();
        HealthRecord nullTime = metric(202L, "heart_rate", "72", "device", LocalDateTime.now());
        nullTime.setRecordedAt(null);
        assertThat((Object) invoke(
                "analyzeRecord",
                new Class<?>[]{HealthRecord.class, List.class},
                nullTime,
                List.of(nullTime)
        )).isNotNull();

        LocalDate currentDate = LocalDate.now();
        LocalDateTime early = currentDate.minusDays(1).atTime(8, 0);
        LocalDateTime late = currentDate.minusDays(1).atTime(9, 0);
        HealthRecord earlyRecord = metric(203L, "heart_rate", "70", "device", early);
        HealthRecord lateRecord = metric(204L, "heart_rate", "72", "device", late);
        Map<?, ?> forward = invoke(
                "historicalDailyVectors",
                new Class<?>[]{List.class, LocalDate.class},
                List.of(earlyRecord, lateRecord),
                currentDate
        );
        Map<?, ?> reverse = invoke(
                "historicalDailyVectors",
                new Class<?>[]{List.class, LocalDate.class},
                List.of(lateRecord, earlyRecord),
                currentDate
        );
        assertThat(forward).hasSize(1);
        assertThat(reverse).hasSize(1);

        Object belowThreshold = invoke(
                "diagonalMultivariateSignal",
                new Class<?>[]{List.class, Map.class},
                List.of("heart_rate", "weight"),
                Map.of("heart_rate", 1.0, "weight", 1.0)
        );
        Object aboveThreshold = invoke(
                "diagonalMultivariateSignal",
                new Class<?>[]{List.class, Map.class},
                List.of("heart_rate", "weight"),
                Map.of("heart_rate", 4.0, "weight", 4.0)
        );
        Object missingFeature = invoke(
                "diagonalMultivariateSignal",
                new Class<?>[]{List.class, Map.class},
                List.of("heart_rate", "weight"),
                Map.of("heart_rate", 4.0)
        );
        assertThat(belowThreshold).isNotNull();
        assertThat(aboveThreshold).isNotNull();
        assertThat(missingFeature).isNotNull();
    }

    private HealthRecord metric(
            Long id,
            String type,
            String value,
            String source,
            LocalDateTime recordedAt
    ) {
        HealthRecord record = new HealthRecord();
        record.setId(id);
        record.setUserId(7L);
        record.setType(type);
        record.setValue(new BigDecimal(value));
        record.setSource(source);
        record.setRecordedAt(recordedAt);
        return record;
    }

    private LocalDateTime atHour(int hour) {
        return LocalDateTime.now().withHour(hour).withMinute(0).withSecond(0).withNano(0);
    }

    @SuppressWarnings("unchecked")
    private <T> T invoke(String methodName, Class<?>[] parameterTypes, Object... arguments) {
        try {
            Method method = AdaptiveRiskAnalyzer.class.getDeclaredMethod(methodName, parameterTypes);
            method.setAccessible(true);
            return (T) method.invoke(analyzer, arguments);
        } catch (NoSuchMethodException | IllegalAccessException exception) {
            throw new AssertionError(exception);
        } catch (InvocationTargetException exception) {
            throw new AssertionError(exception.getCause());
        }
    }
}

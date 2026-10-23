package com.ankang.assistant.eventmesh.service;

import com.ankang.assistant.health.entity.HealthRecord;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class AdaptiveRiskAnalyzerTest {

    private final AdaptiveRiskAnalyzer analyzer = new AdaptiveRiskAnalyzer();

    @Test
    void detectsWithinRangeHeartRateThatStronglyDeviatesFromPersonalBaseline() {
        LocalDateTime now = LocalDateTime.now().withHour(9);
        List<HealthRecord> records = new ArrayList<>();
        for (int day = 14; day >= 1; day--) {
            records.add(metric(
                    (long) day,
                    "heart_rate",
                    Integer.toString(68 + day % 5),
                    now.minusDays(day),
                    "smart_band"
            ));
        }
        HealthRecord current = metric(99L, "heart_rate", "96", now, "smart_band");
        records.add(current);

        AdaptiveRiskResult result = analyzer.analyze(
                current,
                Map.of("heart_rate", current),
                records
        );

        assertThat(result.score()).isPositive();
        assertThat(result.currentScore()).isPositive();
        assertThat(result.reasons())
                .anyMatch(reason -> reason.contains("个人基线")
                        && reason.contains("心率")
                        && reason.contains("MAD"));
        assertThat(result.reasons())
                .anyMatch(reason -> reason.contains("智能手环")
                        && reason.contains(AdaptiveRiskAnalyzer.ALGORITHM_VERSION));
    }

    @Test
    void stableReadingDoesNotTriggerPersonalizedRisk() {
        LocalDateTime now = LocalDateTime.now().withHour(9);
        List<HealthRecord> records = new ArrayList<>();
        for (int day = 14; day >= 1; day--) {
            records.add(metric(
                    (long) day,
                    "heart_rate",
                    Integer.toString(70 + day % 3),
                    now.minusDays(day),
                    "smart_band"
            ));
        }
        HealthRecord current = metric(99L, "heart_rate", "72", now, "smart_band");
        records.add(current);

        AdaptiveRiskResult result = analyzer.analyze(
                current,
                Map.of("heart_rate", current),
                records
        );

        assertThat(result.score()).isZero();
        assertThat(result.reasons()).isEmpty();
    }

    @Test
    void returnsNoRiskForMissingHistoryOrUnsupportedMetric() {
        assertThat(analyzer.analyze(null, Map.of(), List.of()).score()).isZero();
        assertThat(analyzer.analyze(null, null, null).score()).isZero();

        HealthRecord unsupported = metric(
                300L,
                "temperature",
                "36.5",
                LocalDateTime.now(),
                "manual"
        );
        AdaptiveRiskResult result = analyzer.analyze(
                unsupported,
                Map.of("temperature", unsupported),
                List.of(unsupported)
        );

        assertThat(result.score()).isZero();
        assertThat(result.reasons()).isEmpty();
    }

    @Test
    void detectsStrongDownwardWeightTrendFromManualMeasurements() {
        LocalDateTime now = LocalDateTime.now().withHour(8);
        List<HealthRecord> records = new ArrayList<>();
        for (int day = 14; day >= 1; day--) {
            records.add(metric(
                    (long) (400 + day),
                    "weight",
                    "80",
                    now.minusDays(day),
                    "manual"
            ));
        }
        HealthRecord current = metric(500L, "weight", "70", now, "manual");
        records.add(current);

        AdaptiveRiskResult result = analyzer.analyze(
                current,
                Map.of("weight", current),
                records
        );

        assertThat(result.score()).isPositive();
        assertThat(result.currentScore()).isPositive();
        assertThat(result.reasons()).anyMatch(reason -> reason.contains("体重"));
        assertThat(result.reasons()).anyMatch(reason -> reason.contains("持续下降"));
    }

    @Test
    void detectsJointDeviationAcrossBloodPressureHeartRateAndGlucose() {
        LocalDateTime now = LocalDateTime.now().withHour(9);
        List<HealthRecord> records = new ArrayList<>();
        for (int day = 14; day >= 1; day--) {
            LocalDateTime recordedAt = now.minusDays(day);
            HealthRecord pressure = pressure(
                    (long) (day * 10),
                    116 + day % 3,
                    74 + day % 2,
                    recordedAt,
                    "health_connect"
            );
            records.add(pressure);
            records.add(metric(
                    (long) (day * 10 + 1),
                    "heart_rate",
                    Integer.toString(68 + day % 4),
                    recordedAt.plusMinutes(1),
                    "health_connect"
            ));
            records.add(metric(
                    (long) (day * 10 + 2),
                    "blood_glucose",
                    day % 2 == 0 ? "5.0" : "5.2",
                    recordedAt.plusMinutes(2),
                    "health_connect"
            ));
        }

        HealthRecord currentPressure = pressure(900L, 136, 87, now, "health_connect");
        HealthRecord currentHeartRate =
                metric(901L, "heart_rate", "96", now.plusMinutes(1), "health_connect");
        HealthRecord currentGlucose =
                metric(902L, "blood_glucose", "6.0", now.plusMinutes(2), "health_connect");
        records.add(currentPressure);
        records.add(currentHeartRate);
        records.add(currentGlucose);
        Map<String, HealthRecord> latest = new LinkedHashMap<>();
        latest.put("blood_pressure", currentPressure);
        latest.put("heart_rate", currentHeartRate);
        latest.put("blood_glucose", currentGlucose);

        AdaptiveRiskResult result = analyzer.analyze(
                currentHeartRate,
                latest,
                records
        );

        assertThat(result.score()).isGreaterThanOrEqualTo(30);
        assertThat(result.reasons())
                .anyMatch(reason -> reason.contains("多指标联合异常")
                        && reason.contains("马氏距离"));
    }

    private HealthRecord pressure(
            Long id,
            int systolic,
            int diastolic,
            LocalDateTime recordedAt,
            String source
    ) {
        HealthRecord record = metric(
                id,
                "blood_pressure",
                Integer.toString(systolic),
                recordedAt,
                source
        );
        record.setSystolic(systolic);
        record.setDiastolic(diastolic);
        return record;
    }

    private HealthRecord metric(
            Long id,
            String type,
            String value,
            LocalDateTime recordedAt,
            String source
    ) {
        HealthRecord record = new HealthRecord();
        record.setId(id);
        record.setUserId(7L);
        record.setType(type);
        record.setValue(new BigDecimal(value));
        record.setRecordedAt(recordedAt);
        record.setSource(source);
        return record;
    }
}

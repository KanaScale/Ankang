package com.ankang.assistant.eventmesh.service;

import com.ankang.assistant.health.entity.HealthRecord;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;

/**
 * 个体化健康异常分析器。
 *
 * <p>采用鲁棒 MAD 基线、EWMA/CUSUM 趋势检测与收缩协方差马氏距离。
 * 医学固定阈值仍由 {@link RiskEngineService} 负责，本类只提供个体化增量，
 * 避免统计模型覆盖医学安全红线。</p>
 */
@Component
public class AdaptiveRiskAnalyzer {

    static final String ALGORITHM_VERSION = "hybrid-risk-v1";
    private static final int MIN_BASELINE_SAMPLES = 7;
    private static final int MIN_MULTIVARIATE_DAYS = 7;
    private static final double EWMA_ALPHA = 0.35;
    private static final double CUSUM_ALLOWANCE = 0.5;
    private static final double COVARIANCE_SHRINKAGE = 0.25;
    private static final double MATRIX_RIDGE = 0.10;

    public AdaptiveRiskResult analyze(
            HealthRecord current,
            Map<String, HealthRecord> latest,
            List<HealthRecord> records
    ) {
        if (records == null || records.isEmpty() || latest == null || latest.isEmpty()) {
            return AdaptiveRiskResult.none();
        }

        int totalScore = 0;
        int currentScore = 0;
        List<String> reasons = new ArrayList<>();
        Map<String, Double> latestRobustZ = new LinkedHashMap<>();

        for (HealthRecord record : latest.values()) {
            boolean isCurrent = sameRecord(current, record);
            RecordAnalysis analysis = analyzeRecord(record, records);
            if (analysis.score() > 0) {
                totalScore += analysis.score();
                if (isCurrent) {
                    currentScore += analysis.score();
                }
                String prefix = isCurrent ? "个体基线：" : "关联指标个体基线：";
                analysis.reasons().forEach(reason -> reasons.add(prefix + reason));
            }
            latestRobustZ.putAll(analysis.robustZByFeature());
        }

        MultivariateSignal multivariate = analyzeMultivariate(latest, records, latestRobustZ);
        if (multivariate.score() > 0) {
            totalScore += multivariate.score();
            currentScore += multivariate.score();
            reasons.add(multivariate.reason());
        }

        if (totalScore == 0) {
            return AdaptiveRiskResult.none();
        }

        double confidence = dataConfidence(current, records);
        int adjustedScore = Math.max(1, (int) Math.round(totalScore * confidence));
        int adjustedCurrentScore = Math.max(
                currentScore > 0 ? 1 : 0,
                (int) Math.round(currentScore * confidence)
        );
        reasons.add("数据可信度：" + sourceLabel(current)
                + "，个体模型置信系数 " + percent(confidence)
                + "（算法 " + ALGORITHM_VERSION + "）");
        return new AdaptiveRiskResult(
                Math.min(adjustedScore, 45),
                Math.min(adjustedCurrentScore, 35),
                List.copyOf(reasons)
        );
    }

    private RecordAnalysis analyzeRecord(HealthRecord record, List<HealthRecord> records) {
        if (record == null || record.getType() == null || record.getRecordedAt() == null) {
            return RecordAnalysis.none();
        }

        List<FeatureSpec> features = featuresOf(record);
        if (features.isEmpty()) {
            return RecordAnalysis.none();
        }

        int score = 0;
        List<String> reasons = new ArrayList<>();
        Map<String, Double> robustZByFeature = new LinkedHashMap<>();
        for (FeatureSpec feature : features) {
            List<TimedValue> history = historyFor(feature, record, records);
            BaselineSignal baseline = baselineSignal(feature, history);
            robustZByFeature.put(feature.key(), baseline.robustZ());
            if (baseline.score() > 0) {
                score += baseline.score();
                reasons.add(baseline.reason());
            }

            TrendSignal trend = trendSignal(feature, history);
            if (trend.score() > 0) {
                score += trend.score();
                reasons.add(trend.reason());
            }
        }
        return new RecordAnalysis(
                Math.min(score, 30),
                List.copyOf(reasons),
                Map.copyOf(robustZByFeature)
        );
    }

    private BaselineSignal baselineSignal(FeatureSpec feature, List<TimedValue> history) {
        List<TimedValue> comparable = samePeriodHistory(feature.recordedAt(), history);
        if (comparable.size() < MIN_BASELINE_SAMPLES) {
            comparable = history;
        }
        if (comparable.size() < MIN_BASELINE_SAMPLES) {
            return BaselineSignal.none();
        }

        double[] values = comparable.stream().mapToDouble(TimedValue::value).toArray();
        double median = median(values);
        double mad = median(Arrays.stream(values).map(value -> Math.abs(value - median)).toArray());
        double scale = Math.max(1.4826 * mad, feature.minimumScale());
        double robustZ = Math.abs(feature.currentValue() - median) / scale;
        int score;
        if (robustZ >= 4.0) {
            score = 24;
        } else if (robustZ >= 3.0) {
            score = 18;
        } else if (robustZ >= 2.5) {
            score = 12;
        } else {
            score = 0;
        }

        if (score == 0) {
            return new BaselineSignal(0, robustZ, null);
        }
        double lower = median - scale;
        double upper = median + scale;
        String reason = feature.label() + "为 " + number(feature.currentValue()) + feature.unit()
                + "，个人基线约 " + number(lower) + "～" + number(upper) + feature.unit()
                + "，偏离 " + number(robustZ) + " MAD";
        return new BaselineSignal(score, robustZ, reason);
    }

    private TrendSignal trendSignal(FeatureSpec feature, List<TimedValue> history) {
        if (history.size() < MIN_BASELINE_SAMPLES) {
            return TrendSignal.none();
        }

        List<TimedValue> ordered = history.stream()
                .sorted(Comparator.comparing(TimedValue::recordedAt))
                .toList();
        double[] baselineValues = ordered.stream()
                .mapToDouble(TimedValue::value)
                .toArray();
        double center = median(baselineValues);
        double mad = median(Arrays.stream(baselineValues)
                .map(value -> Math.abs(value - center))
                .toArray());
        double scale = Math.max(1.4826 * mad, feature.minimumScale());

        double ewma = ordered.get(0).value();
        double positiveCusum = 0;
        double negativeCusum = 0;
        for (TimedValue item : ordered) {
            ewma = EWMA_ALPHA * item.value() + (1 - EWMA_ALPHA) * ewma;
            double standardized = (item.value() - center) / scale;
            positiveCusum = Math.max(0, positiveCusum + standardized - CUSUM_ALLOWANCE);
            negativeCusum = Math.max(0, negativeCusum - standardized - CUSUM_ALLOWANCE);
        }
        ewma = EWMA_ALPHA * feature.currentValue() + (1 - EWMA_ALPHA) * ewma;
        double currentStandardized = (feature.currentValue() - center) / scale;
        positiveCusum = Math.max(0, positiveCusum + currentStandardized - CUSUM_ALLOWANCE);
        negativeCusum = Math.max(0, negativeCusum - currentStandardized - CUSUM_ALLOWANCE);

        double ewmaDeviation = Math.abs(ewma - center) / scale;
        double cusum = Math.max(positiveCusum, negativeCusum);
        if (ewmaDeviation < 1.5 || cusum < 4.0) {
            return TrendSignal.none();
        }
        int score = ewmaDeviation >= 2.5 || cusum >= 8 ? 12 : 8;
        String direction = ewma >= center ? "持续上升" : "持续下降";
        return new TrendSignal(
                score,
                feature.label() + "出现" + direction + "趋势（EWMA 偏离 "
                        + number(ewmaDeviation) + "，CUSUM " + number(cusum) + "）"
        );
    }

    private MultivariateSignal analyzeMultivariate(
            Map<String, HealthRecord> latest,
            List<HealthRecord> records,
            Map<String, Double> latestRobustZ
    ) {
        Map<String, Double> currentVector = currentFeatureVector(latest);
        if (currentVector.size() < 2) {
            return MultivariateSignal.none();
        }

        List<String> featureKeys = currentVector.keySet().stream()
                .filter(key -> historicalFeatureCount(records, key) >= MIN_MULTIVARIATE_DAYS)
                .toList();
        if (featureKeys.size() < 2) {
            return MultivariateSignal.none();
        }

        LocalDate currentDate = latest.values().stream()
                .map(HealthRecord::getRecordedAt)
                .filter(Objects::nonNull)
                .map(LocalDateTime::toLocalDate)
                .max(LocalDate::compareTo)
                .orElse(LocalDate.now());
        Map<LocalDate, Map<String, Double>> daily = historicalDailyVectors(records, currentDate);
        if (daily.size() < MIN_MULTIVARIATE_DAYS) {
            return MultivariateSignal.none();
        }

        int dimension = featureKeys.size();
        double[] centers = new double[dimension];
        double[] scales = new double[dimension];
        for (int index = 0; index < dimension; index++) {
            String key = featureKeys.get(index);
            double[] values = daily.values().stream()
                    .map(day -> day.get(key))
                    .filter(Objects::nonNull)
                    .mapToDouble(Double::doubleValue)
                    .toArray();
            if (values.length < MIN_MULTIVARIATE_DAYS) {
                return MultivariateSignal.none();
            }
            centers[index] = median(values);
            double center = centers[index];
            double mad = median(Arrays.stream(values)
                    .map(value -> Math.abs(value - center))
                    .toArray());
            scales[index] = Math.max(1.4826 * mad, minimumScale(key));
        }

        List<double[]> samples = new ArrayList<>();
        for (Map<String, Double> day : daily.values()) {
            double[] vector = new double[dimension];
            for (int index = 0; index < dimension; index++) {
                Double value = day.get(featureKeys.get(index));
                vector[index] = value == null ? 0 : (value - centers[index]) / scales[index];
            }
            samples.add(vector);
        }
        double[][] covariance = shrunkCovariance(samples, dimension);
        double[][] inverse = invert(covariance);
        if (inverse == null) {
            return diagonalMultivariateSignal(featureKeys, latestRobustZ);
        }

        double[] current = new double[dimension];
        for (int index = 0; index < dimension; index++) {
            current[index] = (currentVector.get(featureKeys.get(index)) - centers[index]) / scales[index];
        }
        double distanceSquared = quadraticForm(current, inverse);
        double warningThreshold = chiSquareThreshold95(dimension);
        double highThreshold = chiSquareThreshold99(dimension);
        if (distanceSquared < warningThreshold) {
            return MultivariateSignal.none();
        }
        int score = distanceSquared >= highThreshold ? 18 : 10;
        return new MultivariateSignal(
                score,
                "多指标联合异常：血压、心率或血糖的组合偏离个人历史模式"
                        + "（收缩马氏距离²=" + number(distanceSquared) + "）"
        );
    }

    private MultivariateSignal diagonalMultivariateSignal(
            List<String> featureKeys,
            Map<String, Double> latestRobustZ
    ) {
        double sum = featureKeys.stream()
                .map(latestRobustZ::get)
                .filter(Objects::nonNull)
                .mapToDouble(value -> value * value)
                .sum();
        if (sum < chiSquareThreshold95(featureKeys.size())) {
            return MultivariateSignal.none();
        }
        return new MultivariateSignal(
                10,
                "多指标联合异常：多个指标同时偏离个人基线"
                        + "（对角马氏距离²=" + number(sum) + "）"
        );
    }

    private List<TimedValue> historyFor(
            FeatureSpec feature,
            HealthRecord current,
            List<HealthRecord> records
    ) {
        return records.stream()
                .filter(record -> record != null && record.getRecordedAt() != null)
                .filter(record -> !sameRecord(current, record))
                .filter(record -> record.getRecordedAt().isBefore(feature.recordedAt()))
                .map(record -> featureValue(record, feature.key()))
                .filter(Objects::nonNull)
                .map(value -> new TimedValue(value.value(), value.recordedAt()))
                .toList();
    }

    private List<TimedValue> samePeriodHistory(
            LocalDateTime currentTime,
            List<TimedValue> history
    ) {
        int bucket = timeBucket(currentTime);
        return history.stream()
                .filter(value -> timeBucket(value.recordedAt()) == bucket)
                .toList();
    }

    private List<FeatureSpec> featuresOf(HealthRecord record) {
        List<FeatureSpec> result = new ArrayList<>();
        if ("blood_pressure".equals(record.getType())) {
            if (record.getSystolic() != null) {
                result.add(new FeatureSpec(
                        "systolic", "收缩压", record.getSystolic(), " mmHg",
                        5.0, record.getRecordedAt()
                ));
            }
            if (record.getDiastolic() != null) {
                result.add(new FeatureSpec(
                        "diastolic", "舒张压", record.getDiastolic(), " mmHg",
                        4.0, record.getRecordedAt()
                ));
            }
            return result;
        }
        BigDecimal value = valueOf(record);
        if (value == null) {
            return result;
        }
        switch (record.getType()) {
            case "heart_rate" -> result.add(new FeatureSpec(
                    "heart_rate", "心率", value.doubleValue(), " bpm",
                    3.0, record.getRecordedAt()
            ));
            case "blood_glucose" -> result.add(new FeatureSpec(
                    "blood_glucose", "血糖", value.doubleValue(), " mmol/L",
                    0.30, record.getRecordedAt()
            ));
            case "weight" -> result.add(new FeatureSpec(
                    "weight", "体重", value.doubleValue(), " kg",
                    0.50, record.getRecordedAt()
            ));
            default -> {
                // 未知指标仍由医学规则和状态字段处理，不进入个体模型。
            }
        }
        return result;
    }

    private Map<String, Double> currentFeatureVector(Map<String, HealthRecord> latest) {
        Map<String, Double> vector = new LinkedHashMap<>();
        latest.values().stream()
                .flatMap(record -> featuresOf(record).stream())
                .forEach(feature -> vector.put(feature.key(), feature.currentValue()));
        return vector;
    }

    private Map<LocalDate, Map<String, Double>> historicalDailyVectors(
            List<HealthRecord> records,
            LocalDate currentDate
    ) {
        Map<LocalDate, Map<String, TimedValue>> dailyTimed = new HashMap<>();
        records.stream()
                .filter(record -> record != null && record.getRecordedAt() != null)
                .filter(record -> record.getRecordedAt().toLocalDate().isBefore(currentDate))
                .forEach(record -> {
                    LocalDate date = record.getRecordedAt().toLocalDate();
                    Map<String, TimedValue> day = dailyTimed.computeIfAbsent(date, ignored -> new HashMap<>());
                    for (FeatureSpec feature : featuresOf(record)) {
                        TimedValue previous = day.get(feature.key());
                        if (previous == null || previous.recordedAt().isBefore(record.getRecordedAt())) {
                            day.put(feature.key(), new TimedValue(feature.currentValue(), record.getRecordedAt()));
                        }
                    }
                });
        Map<LocalDate, Map<String, Double>> result = new HashMap<>();
        dailyTimed.forEach((date, values) -> {
            Map<String, Double> vector = new HashMap<>();
            values.forEach((key, value) -> vector.put(key, value.value()));
            result.put(date, vector);
        });
        return result;
    }

    private int historicalFeatureCount(List<HealthRecord> records, String key) {
        return (int) records.stream()
                .map(record -> featureValue(record, key))
                .filter(Objects::nonNull)
                .map(value -> value.recordedAt().toLocalDate())
                .distinct()
                .count();
    }

    private TimedValue featureValue(HealthRecord record, String key) {
        if (record == null || record.getRecordedAt() == null) {
            return null;
        }
        Double value = switch (key) {
            case "systolic" -> record.getSystolic() == null ? null : record.getSystolic().doubleValue();
            case "diastolic" -> record.getDiastolic() == null ? null : record.getDiastolic().doubleValue();
            case "heart_rate" -> "heart_rate".equals(record.getType()) && valueOf(record) != null
                    ? valueOf(record).doubleValue() : null;
            case "blood_glucose" -> "blood_glucose".equals(record.getType()) && valueOf(record) != null
                    ? valueOf(record).doubleValue() : null;
            case "weight" -> "weight".equals(record.getType()) && valueOf(record) != null
                    ? valueOf(record).doubleValue() : null;
            default -> null;
        };
        return value == null ? null : new TimedValue(value, record.getRecordedAt());
    }

    private double[][] shrunkCovariance(List<double[]> samples, int dimension) {
        double[] means = new double[dimension];
        for (double[] sample : samples) {
            for (int index = 0; index < dimension; index++) {
                means[index] += sample[index];
            }
        }
        for (int index = 0; index < dimension; index++) {
            means[index] /= samples.size();
        }

        double[][] covariance = new double[dimension][dimension];
        for (double[] sample : samples) {
            for (int row = 0; row < dimension; row++) {
                for (int column = 0; column < dimension; column++) {
                    covariance[row][column] +=
                            (sample[row] - means[row]) * (sample[column] - means[column]);
                }
            }
        }
        double divisor = Math.max(1, samples.size() - 1);
        for (int row = 0; row < dimension; row++) {
            for (int column = 0; column < dimension; column++) {
                covariance[row][column] /= divisor;
                if (row != column) {
                    covariance[row][column] *= (1 - COVARIANCE_SHRINKAGE);
                }
            }
            covariance[row][row] =
                    (1 - COVARIANCE_SHRINKAGE) * covariance[row][row]
                            + COVARIANCE_SHRINKAGE
                            + MATRIX_RIDGE;
        }
        return covariance;
    }

    private double[][] invert(double[][] matrix) {
        int size = matrix.length;
        double[][] augmented = new double[size][size * 2];
        for (int row = 0; row < size; row++) {
            System.arraycopy(matrix[row], 0, augmented[row], 0, size);
            augmented[row][row + size] = 1;
        }
        for (int pivot = 0; pivot < size; pivot++) {
            int best = pivot;
            for (int row = pivot + 1; row < size; row++) {
                if (Math.abs(augmented[row][pivot]) > Math.abs(augmented[best][pivot])) {
                    best = row;
                }
            }
            if (Math.abs(augmented[best][pivot]) < 1e-9) {
                return null;
            }
            double[] temporary = augmented[pivot];
            augmented[pivot] = augmented[best];
            augmented[best] = temporary;

            double pivotValue = augmented[pivot][pivot];
            for (int column = 0; column < size * 2; column++) {
                augmented[pivot][column] /= pivotValue;
            }
            for (int row = 0; row < size; row++) {
                if (row == pivot) {
                    continue;
                }
                double factor = augmented[row][pivot];
                for (int column = 0; column < size * 2; column++) {
                    augmented[row][column] -= factor * augmented[pivot][column];
                }
            }
        }
        double[][] result = new double[size][size];
        for (int row = 0; row < size; row++) {
            System.arraycopy(augmented[row], size, result[row], 0, size);
        }
        return result;
    }

    private double quadraticForm(double[] vector, double[][] matrix) {
        double result = 0;
        for (int row = 0; row < vector.length; row++) {
            for (int column = 0; column < vector.length; column++) {
                result += vector[row] * matrix[row][column] * vector[column];
            }
        }
        return Math.max(0, result);
    }

    private double dataConfidence(HealthRecord current, List<HealthRecord> records) {
        double sourceConfidence = switch (normalizedSource(current)) {
            case "health_connect", "medical_device" -> 0.98;
            case "smart_band", "wearable", "device", "watch" -> 0.93;
            case "manual" -> 0.82;
            default -> 0.74;
        };
        String type = current == null ? null : current.getType();
        long sampleCount = records.stream()
                .filter(record -> type != null && type.equals(record.getType()))
                .count();
        double sampleConfidence = Math.min(1.0, 0.65 + sampleCount / 40.0);
        return Math.max(0.60, Math.min(1.0, sourceConfidence * sampleConfidence));
    }

    private String sourceLabel(HealthRecord current) {
        return switch (normalizedSource(current)) {
            case "health_connect" -> "Health Connect";
            case "medical_device" -> "医疗设备";
            case "smart_band", "wearable", "device", "watch" -> "智能手环/可穿戴设备";
            case "manual" -> "用户手动录入";
            default -> "来源未标记";
        };
    }

    private String normalizedSource(HealthRecord current) {
        if (current == null || current.getSource() == null) {
            return "";
        }
        return current.getSource().trim().toLowerCase(Locale.ROOT);
    }

    private boolean sameRecord(HealthRecord left, HealthRecord right) {
        if (left == null || right == null) {
            return false;
        }
        if (left.getId() != null && right.getId() != null) {
            return left.getId().equals(right.getId());
        }
        return left == right;
    }

    private BigDecimal valueOf(HealthRecord record) {
        return record == null
                ? null
                : record.getValue() != null ? record.getValue() : record.getValue1();
    }

    private int timeBucket(LocalDateTime value) {
        int hour = value.getHour();
        if (hour >= 5 && hour < 12) {
            return 0;
        }
        if (hour >= 12 && hour < 18) {
            return 1;
        }
        if (hour >= 18 && hour < 23) {
            return 2;
        }
        return 3;
    }

    private double minimumScale(String key) {
        return switch (key) {
            case "systolic" -> 5.0;
            case "diastolic" -> 4.0;
            case "heart_rate" -> 3.0;
            case "blood_glucose" -> 0.30;
            case "weight" -> 0.50;
            default -> 1.0;
        };
    }

    private double median(double[] source) {
        if (source.length == 0) {
            return 0;
        }
        double[] values = Arrays.copyOf(source, source.length);
        Arrays.sort(values);
        int middle = values.length / 2;
        return values.length % 2 == 0
                ? (values[middle - 1] + values[middle]) / 2
                : values[middle];
    }

    private double chiSquareThreshold95(int dimension) {
        return switch (dimension) {
            case 2 -> 5.99;
            case 3 -> 7.81;
            default -> 9.49;
        };
    }

    private double chiSquareThreshold99(int dimension) {
        return switch (dimension) {
            case 2 -> 9.21;
            case 3 -> 11.34;
            default -> 13.28;
        };
    }

    private String number(double value) {
        return BigDecimal.valueOf(value)
                .setScale(2, RoundingMode.HALF_UP)
                .stripTrailingZeros()
                .toPlainString();
    }

    private String percent(double value) {
        return Math.round(value * 100) + "%";
    }

    private record FeatureSpec(
            String key,
            String label,
            double currentValue,
            String unit,
            double minimumScale,
            LocalDateTime recordedAt
    ) {
    }

    private record TimedValue(double value, LocalDateTime recordedAt) {
    }

    private record BaselineSignal(int score, double robustZ, String reason) {
        static BaselineSignal none() {
            return new BaselineSignal(0, 0, null);
        }
    }

    private record TrendSignal(int score, String reason) {
        static TrendSignal none() {
            return new TrendSignal(0, null);
        }
    }

    private record MultivariateSignal(int score, String reason) {
        static MultivariateSignal none() {
            return new MultivariateSignal(0, null);
        }
    }

    private record RecordAnalysis(
            int score,
            List<String> reasons,
            Map<String, Double> robustZByFeature
    ) {
        static RecordAnalysis none() {
            return new RecordAnalysis(0, List.of(), Map.of());
        }
    }
}

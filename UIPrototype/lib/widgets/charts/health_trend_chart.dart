import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../models/health_record_model.dart';

class HealthTrendChart extends StatelessWidget {
  const HealthTrendChart({
    super.key,
    required this.points,
    required this.type,
  });

  final List<HealthTrendPoint> points;
  final HealthRecordType type;

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var index = 0; index < points.length; index++)
        FlSpot(index.toDouble(), points[index].value),
    ];
    final values = points.map((point) => point.value).toList();
    final referenceLines = _referenceLines(type);
    final axisValues = [
      ...values,
      for (final line in referenceLines) line.value,
    ];
    final min =
        axisValues.isEmpty ? 0.0 : axisValues.reduce((a, b) => a < b ? a : b);
    final max =
        axisValues.isEmpty ? 1.0 : axisValues.reduce((a, b) => a > b ? a : b);
    final padding = ((max - min).abs() * 0.18).clamp(4, 20).toDouble();

    if (spots.isEmpty) {
      return const Center(child: Text('暂无趋势数据'));
    }

    return LineChart(
      LineChartData(
        minY: min - padding,
        maxY: max + padding,
        extraLinesData: ExtraLinesData(
          extraLinesOnTop: false,
          horizontalLines: [
            for (final line in referenceLines)
              HorizontalLine(
                y: line.value,
                color: line.color.withValues(alpha: 0.46),
                strokeWidth: 1.4,
                dashArray: const [6, 5],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: line.color,
                        fontWeight: FontWeight.w700,
                      ),
                  labelResolver: (_) => line.label,
                ),
              ),
          ],
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppColors.border,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(0),
                  style: Theme.of(context).textTheme.bodySmall,
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                final date = points[index].time;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${date.month}/${date.day}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.textPrimary,
            getTooltipItems: (items) {
              return items.map((item) {
                return LineTooltipItem(
                  '${item.y.toStringAsFixed(1)} ${type.defaultUnit}',
                  const TextStyle(color: Colors.white),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.28,
            barWidth: 4,
            color: _lineColor(type),
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: _lineColor(type).withValues(alpha: 0.14),
            ),
          ),
        ],
      ),
    );
  }

  Color _lineColor(HealthRecordType type) {
    return switch (type) {
      HealthRecordType.bloodPressure => AppColors.chartBlue,
      HealthRecordType.bloodSugar => AppColors.chartOrange,
      HealthRecordType.heartRate => AppColors.emergency,
      HealthRecordType.weight => AppColors.primary,
      HealthRecordType.other => AppColors.chartPurple,
    };
  }

  List<_ReferenceLine> _referenceLines(HealthRecordType type) {
    return switch (type) {
      HealthRecordType.bloodPressure => const [
          _ReferenceLine(140, '140', AppColors.warning),
        ],
      HealthRecordType.bloodSugar => const [
          _ReferenceLine(7, '7.0', AppColors.warning),
        ],
      HealthRecordType.heartRate => const [
          _ReferenceLine(100, '100', AppColors.warning),
          _ReferenceLine(60, '60', AppColors.chartBlue),
        ],
      HealthRecordType.weight => const [],
      HealthRecordType.other => const [],
    };
  }
}

class _ReferenceLine {
  const _ReferenceLine(this.value, this.label, this.color);

  final double value;
  final String label;
  final Color color;
}

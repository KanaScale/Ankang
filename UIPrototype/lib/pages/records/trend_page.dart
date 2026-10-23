import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../models/health_record_model.dart';
import '../../services/record_service.dart';
import '../../widgets/charts/chart_container.dart';
import '../../widgets/charts/health_trend_chart.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/loading_view.dart';
import '../../widgets/glass_card.dart';

class TrendPage extends StatefulWidget {
  const TrendPage({
    super.key,
    this.initialType = HealthRecordType.bloodPressure,
  });

  final HealthRecordType initialType;

  @override
  State<TrendPage> createState() => _TrendPageState();
}

class _TrendPageState extends State<TrendPage> {
  final _recordService = RecordService();
  late HealthRecordType _type;
  var _range = '7d';
  HealthTrendSummary? _summary;
  var _loading = true;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _loadTrend();
  }

  Future<void> _loadTrend() async {
    setState(() {
      _loading = true;
      _notice = null;
    });
    try {
      final response = await _recordService.getTrend(
        type: _type,
        range: _range,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _summary = response.data ?? _sampleTrend(_type, _range);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _summary = _sampleTrend(_type, _range);
        _notice = '后端趋势接口暂不可用，当前展示演示数据';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('趋势分析')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _TrendHero(type: _type, summary: summary),
            const SizedBox(height: AppSpacing.lg),
            _TrendControls(
              type: _type,
              range: _range,
              onTypeChanged: (value) {
                setState(() => _type = value);
                _loadTrend();
              },
              onRangeChanged: (value) {
                setState(() => _range = value);
                _loadTrend();
              },
            ),
            const SizedBox(height: AppSpacing.md),
            if (_notice != null) ...[
              ErrorView(message: _notice!),
              const SizedBox(height: AppSpacing.md),
            ],
            if (_loading)
              const SizedBox(height: 420, child: LoadingView())
            else if (summary != null) ...[
              _StatsGrid(summary: summary),
              const SizedBox(height: AppSpacing.lg),
              ChartContainer(
                title: '${summary.type.label}趋势',
                subtitle: '最近 ${summary.range == '30d' ? '30 天' : '7 天'}',
                child: HealthTrendChart(
                  points: summary.points,
                  type: summary.type,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _AdviceCard(summary: summary),
            ],
          ],
        ),
      ),
    );
  }

  HealthTrendSummary _sampleTrend(HealthRecordType type, String range) {
    final days = range == '30d' ? 30 : 7;
    final now = DateTime.now();
    final base = switch (type) {
      HealthRecordType.bloodPressure => 128.0,
      HealthRecordType.bloodSugar => 6.0,
      HealthRecordType.heartRate => 74.0,
      HealthRecordType.weight => 65.0,
      HealthRecordType.other => 1.0,
    };
    final points = [
      for (var index = days - 1; index >= 0; index--)
        HealthTrendPoint(
          time: now.subtract(Duration(days: index)),
          value: base +
              ((days - index) % 5 - 2) *
                  (type == HealthRecordType.weight ? 0.2 : 2),
        ),
    ];
    final values = points.map((point) => point.value).toList();
    final avg = values.reduce((a, b) => a + b) / values.length;
    final max = values.reduce((a, b) => a > b ? a : b);
    final min = values.reduce((a, b) => a < b ? a : b);
    return HealthTrendSummary(
      type: type,
      range: range,
      points: points,
      avg: avg,
      max: max,
      min: min,
      abnormalCount: type == HealthRecordType.bloodPressure ? 1 : 0,
    );
  }
}

class _TrendControls extends StatelessWidget {
  const _TrendControls({
    required this.type,
    required this.range,
    required this.onTypeChanged,
    required this.onRangeChanged,
  });

  final HealthRecordType type;
  final String range;
  final ValueChanged<HealthRecordType> onTypeChanged;
  final ValueChanged<String> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<HealthRecordType>(
                  initialValue: type,
                  decoration: const InputDecoration(
                    labelText: '指标',
                    prefixIcon: Icon(Icons.monitor_heart_rounded),
                  ),
                  items: const [
                    HealthRecordType.bloodPressure,
                    HealthRecordType.bloodSugar,
                    HealthRecordType.heartRate,
                    HealthRecordType.weight,
                  ].map((item) {
                    return DropdownMenuItem(
                      value: item,
                      child: Text(item.label),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      onTypeChanged(value);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '7d', label: Text('7天')),
              ButtonSegment(value: '30d', label: Text('30天')),
            ],
            selected: {range},
            onSelectionChanged: (value) => onRangeChanged(value.first),
          ),
        ],
      ),
    );
  }
}

class _TrendHero extends StatelessWidget {
  const _TrendHero({
    required this.type,
    required this.summary,
  });

  final HealthRecordType type;
  final HealthTrendSummary? summary;

  @override
  Widget build(BuildContext context) {
    final abnormalCount = summary?.abnormalCount ?? 0;
    final color = abnormalCount > 0 ? AppColors.warning : type.accentColor;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.18),
            Colors.white,
            AppColors.blueSurface,
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.soft,
        border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(type.icon, color: color, size: 30),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${type.label}趋势',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  summary == null
                      ? '正在整理最近的健康数据'
                      : abnormalCount > 0
                          ? '发现 $abnormalCount 次异常，请保持复测'
                          : '近期整体平稳，继续保持记录',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.summary});

  final HealthTrendSummary summary;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.6,
      children: [
        _StatCard(
          label: '平均值',
          value: summary.avg,
          icon: Icons.functions_rounded,
        ),
        _StatCard(
          label: '最大值',
          value: summary.max,
          icon: Icons.north_east_rounded,
        ),
        _StatCard(
          label: '最小值',
          value: summary.min,
          icon: Icons.south_west_rounded,
        ),
        _StatCard(
          label: '异常次数',
          value: summary.abnormalCount.toDouble(),
          unit: '次',
          icon: Icons.warning_amber_rounded,
          highlight: summary.abnormalCount > 0,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.unit,
    this.highlight = false,
  });

  final String label;
  final double value;
  final IconData icon;
  final String? unit;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppColors.warning : AppColors.primary;
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)} ${unit ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension _TrendTypeStyle on HealthRecordType {
  IconData get icon => switch (this) {
        HealthRecordType.bloodPressure => Icons.water_drop_rounded,
        HealthRecordType.bloodSugar => Icons.bloodtype_rounded,
        HealthRecordType.heartRate => Icons.favorite_rounded,
        HealthRecordType.weight => Icons.monitor_weight_rounded,
        HealthRecordType.other => Icons.add_chart_rounded,
      };

  Color get accentColor => switch (this) {
        HealthRecordType.bloodPressure => AppColors.chartBlue,
        HealthRecordType.bloodSugar => AppColors.chartOrange,
        HealthRecordType.heartRate => AppColors.emergency,
        HealthRecordType.weight => AppColors.primary,
        HealthRecordType.other => AppColors.chartPurple,
      };
}

class _AdviceCard extends StatelessWidget {
  const _AdviceCard({required this.summary});

  final HealthTrendSummary summary;

  @override
  Widget build(BuildContext context) {
    final text = summary.abnormalCount > 0
        ? '${summary.type.label}近期存在异常记录，建议固定时间复测；若持续异常，请及时咨询医生。'
        : '${summary.type.label}近期整体平稳，建议继续保持规律记录。';
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.health_and_safety_rounded, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

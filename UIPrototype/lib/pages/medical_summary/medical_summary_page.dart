import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../models/medical_summary_model.dart';
import '../../services/medical_summary_service.dart';
import '../../utils/date_util.dart';
import '../../widgets/app_page_scaffold.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/page_enter_animation.dart';

class MedicalSummaryPage extends StatefulWidget {
  const MedicalSummaryPage({super.key});

  @override
  State<MedicalSummaryPage> createState() => _MedicalSummaryPageState();
}

class _MedicalSummaryPageState extends State<MedicalSummaryPage> {
  final _service = MedicalSummaryService();
  int _days = 14;
  bool _loading = true;
  String? _error;
  MedicalSummaryModel? _summary;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _service.generate(days: _days);
      if (!mounted) return;
      if (!response.success || response.data == null) {
        setState(() => _error =
            response.message.isEmpty ? '就医摘要生成失败，请稍后重试' : response.message);
        return;
      }
      setState(() => _summary = response.data);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _changeRange(int days) async {
    if (days == _days) return;
    setState(() => _days = days);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    return AppPageScaffold(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
      children: [
        _PageHeader(onRefresh: _loading ? null : _load),
        const SizedBox(height: AppSpacing.lg),
        const _PurposeCard(),
        const SizedBox(height: AppSpacing.md),
        _RangeSelector(
          selectedDays: _days,
          enabled: !_loading,
          onSelected: _changeRange,
        ),
        if (_loading && summary == null) ...[
          const SizedBox(height: 96),
          const Center(child: CircularProgressIndicator()),
        ] else if (_error != null && summary == null) ...[
          const SizedBox(height: AppSpacing.xl),
          _LoadError(message: _error!, onRetry: _load),
        ] else if (summary != null) ...[
          if (_loading) ...[
            const SizedBox(height: AppSpacing.sm),
            const LinearProgressIndicator(minHeight: 2),
          ],
          const SizedBox(height: AppSpacing.lg),
          SelectionArea(
            child: Column(
              children: [
                _PatientCard(summary: summary),
                const SizedBox(height: AppSpacing.md),
                _OverviewCard(summary: summary),
                const SizedBox(height: AppSpacing.lg),
                const _SectionTitle(
                  title: '健康指标',
                  subtitle: '统计值来自所选时间范围内的记录',
                ),
                const SizedBox(height: AppSpacing.sm),
                if (summary.metrics.isEmpty)
                  const _EmptySection(message: '所选时间内暂无健康指标记录')
                else
                  ...summary.metrics.map(
                    (metric) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _MetricCard(metric: metric),
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                const _SectionTitle(
                  title: '近期风险提示',
                  subtitle: '展示较高风险和高风险事件，不等同于诊断',
                ),
                const SizedBox(height: AppSpacing.sm),
                if (summary.riskEvents.isEmpty)
                  const _EmptySection(message: '所选时间内未生成需关注的风险事件')
                else
                  ...summary.riskEvents.map(
                    (event) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _RiskEventCard(event: event),
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                const _SectionTitle(
                  title: '用药提醒',
                  subtitle: '仅表示 App 内当前提醒周期的打卡状态',
                ),
                const SizedBox(height: AppSpacing.sm),
                _MedicationCard(summary: summary.medication),
                const SizedBox(height: AppSpacing.lg),
                _SourceAndDisclaimer(summary: summary),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.onRefresh});

  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('就医摘要', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '打开页面即可向医生展示',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: '重新生成',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

class _PurposeCard extends StatelessWidget {
  const _PurposeCard();

  @override
  Widget build(BuildContext context) {
    return PageEnterAnimation(
      child: GlassCard(
        color: AppColors.blueSurface,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0x224F9FA3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.medical_information_rounded,
                color: AppColors.chartBlue,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '客观数据，一页看清',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '自动整理健康档案、指标变化、风险提示和用药提醒。'
                    '本页不包含用户自述，您可以在就诊时当面补充。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.selectedDays,
    required this.enabled,
    required this.onSelected,
  });

  final int selectedDays;
  final bool enabled;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          const Icon(Icons.date_range_rounded, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '数据范围',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 7, label: Text('7天')),
              ButtonSegment(value: 14, label: Text('14天')),
              ButtonSegment(value: 30, label: Text('30天')),
            ],
            selected: {selectedDays},
            onSelectionChanged:
                enabled ? (selection) => onSelected(selection.first) : null,
            style: const ButtonStyle(
              visualDensity: VisualDensity(horizontal: -3, vertical: -2),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientCard extends StatelessWidget {
  const _PatientCard({required this.summary});

  final MedicalSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    final patient = summary.patient;
    final profile = summary.healthProfile;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  patient.displayName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const _ReadOnlyBadge(),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              _InlineInfo(label: '年龄', value: _orDash(patient.age)),
              _InlineInfo(label: '性别', value: _gender(patient.gender)),
              _InlineInfo(
                label: '身高',
                value: profile.height == null
                    ? '--'
                    : '${_number(profile.height!)} cm',
              ),
              _InlineInfo(
                label: '体重',
                value: profile.weight == null
                    ? '--'
                    : '${_number(profile.weight!)} kg',
              ),
              _InlineInfo(
                label: 'BMI',
                value: profile.bmi == null
                    ? '--'
                    : profile.bmi!.toStringAsFixed(1),
              ),
            ],
          ),
          const Divider(height: AppSpacing.xxl),
          _ProfileLine(
            label: '慢性疾病',
            value: profile.chronicDiseases.isEmpty
                ? '未记录'
                : profile.chronicDiseases.join('、'),
          ),
          _ProfileLine(label: '过敏信息', value: _textOrDefault(profile.allergies)),
          _ProfileLine(
              label: '既往史', value: _textOrDefault(profile.medicalHistory)),
          _ProfileLine(label: '关联设备', value: _textOrDefault(profile.device)),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.summary});

  final MedicalSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      color: summary.abnormalRecordCount > 0
          ? AppColors.warmSurface
          : AppColors.blueSurface,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_formatDate(summary.rangeStart)} 至 ${_formatDate(summary.rangeEnd)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _OverviewNumber(
                  value: '${summary.totalRecordCount}',
                  label: '健康记录',
                  color: AppColors.chartBlue,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _OverviewNumber(
                  value: '${summary.abnormalRecordCount}',
                  label: '异常记录',
                  color: summary.abnormalRecordCount > 0
                      ? AppColors.emergency
                      : AppColors.success,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _OverviewNumber(
                  value: '${summary.riskEvents.length}',
                  label: '风险事件',
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final MedicalMetricSummary metric;

  @override
  Widget build(BuildContext context) {
    final abnormal = metric.abnormalCount > 0;
    final unit = metric.unit.isEmpty ? '' : ' ${metric.unit}';
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _metricColor(metric.type).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _metricIcon(metric.type),
                  color: _metricColor(metric.type),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(metric.label,
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      '${metric.recordCount} 次记录 · ${metric.abnormalCount} 次异常',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: abnormal
                                ? AppColors.emergency
                                : AppColors.textTertiary,
                          ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(abnormal: abnormal),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _ValueRow(
            label: '最近一次',
            value: '${metric.latestValue}$unit',
            supporting: _formatDateTime(metric.latestAt),
          ),
          _ValueRow(
            label: '平均值',
            value: metric.averageValue == null
                ? '--'
                : '${metric.averageValue}$unit',
          ),
          _ValueRow(
            label: '范围',
            value: metric.minimumValue == null || metric.maximumValue == null
                ? '--'
                : '${metric.minimumValue} – ${metric.maximumValue}$unit',
            last: true,
          ),
        ],
      ),
    );
  }
}

class _RiskEventCard extends StatelessWidget {
  const _RiskEventCard({required this.event});

  final MedicalRiskEventSummary event;

  @override
  Widget build(BuildContext context) {
    final high = event.riskLevel == 'high';
    final color = high ? AppColors.emergency : AppColors.warning;
    return GlassCard(
      color: high ? AppColors.emergencySoft : AppColors.warmSurface,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: color),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  high
                      ? '高风险 · ${event.riskScore} 分'
                      : '较高风险 · ${event.riskScore} 分',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                _formatDateTime(event.occurredAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          if (event.summary.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(event.summary),
          ],
          if (event.reasons.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ...event.reasons.map(
              (reason) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Icon(Icons.circle, size: 7, color: color),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(reason)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MedicationCard extends StatelessWidget {
  const _MedicationCard({required this.summary});

  final MedicalMedicationSummary summary;

  @override
  Widget build(BuildContext context) {
    if (summary.reminders.isEmpty) {
      return const _EmptySection(message: '当前没有启用的用药提醒');
    }
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '当前周期已完成 ${summary.completedCurrentCycleCount} / ${summary.enabledCount}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          ...summary.reminders.map(
            (reminder) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    reminder.completedCurrentCycle
                        ? Icons.check_circle_rounded
                        : Icons.schedule_rounded,
                    color: reminder.completedCurrentCycle
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(reminder.title,
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '${_repeatLabel(reminder.repeatType)} · ${reminder.schedule}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    reminder.completedCurrentCycle ? '已完成' : '未完成',
                    style: TextStyle(
                      color: reminder.completedCurrentCycle
                          ? AppColors.success
                          : AppColors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceAndDisclaimer extends StatelessWidget {
  const _SourceAndDisclaimer({required this.summary});

  final MedicalSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GlassCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('数据来源', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              if (summary.dataSources.isEmpty)
                const Text('暂无数据来源')
              else
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: summary.dataSources
                      .map(
                        (source) => Chip(
                          avatar: Icon(
                            source.source.contains('band')
                                ? Icons.watch_rounded
                                : Icons.edit_note_rounded,
                            size: 18,
                          ),
                          label:
                              Text('${source.label} ${source.recordCount} 条'),
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '生成时间：${_formatDateTime(summary.generatedAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  summary.disclaimer,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                        height: 1.5,
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyBadge extends StatelessWidget {
  const _ReadOnlyBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.blueSurface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: const Text(
        '只读展示',
        style: TextStyle(
          color: AppColors.chartBlue,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _InlineInfo extends StatelessWidget {
  const _InlineInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label：$value',
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}

class _ProfileLine extends StatelessWidget {
  const _ProfileLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textTertiary,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewNumber extends StatelessWidget {
  const _OverviewNumber({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.abnormal});

  final bool abnormal;

  @override
  Widget build(BuildContext context) {
    final color = abnormal ? AppColors.emergency : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        abnormal ? '有异常' : '均正常',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.label,
    required this.value,
    this.supporting,
    this.last = false,
  });

  final String label;
  final String value;
  final String? supporting;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textTertiary,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          if (supporting != null && supporting!.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              supporting!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              color: AppColors.success),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 48, color: AppColors.emergency),
          const SizedBox(height: AppSpacing.sm),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重新生成'),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime? value) =>
    value == null ? '--' : DateUtil.formatDate(value);

String _formatDateTime(DateTime? value) =>
    value == null ? '--' : DateUtil.formatDateTime(value);

String _textOrDefault(String? value) =>
    value == null || value.trim().isEmpty ? '未记录' : value.trim();

String _orDash(Object? value) => value == null ? '--' : '$value';

String _gender(String? value) => switch (value?.toLowerCase()) {
      'male' || 'm' || '男' => '男',
      'female' || 'f' || '女' => '女',
      _ => _textOrDefault(value),
    };

String _number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);

String _repeatLabel(String value) => switch (value) {
      'daily' => '每日',
      'weekly' => '每周',
      _ => '一次',
    };

IconData _metricIcon(String type) => switch (type) {
      'blood_pressure' => Icons.water_drop_rounded,
      'blood_glucose' => Icons.bloodtype_rounded,
      'heart_rate' => Icons.favorite_rounded,
      'weight' => Icons.monitor_weight_rounded,
      'steps' => Icons.directions_walk_rounded,
      'sleep_hours' => Icons.bedtime_rounded,
      _ => Icons.analytics_rounded,
    };

Color _metricColor(String type) => switch (type) {
      'blood_pressure' => AppColors.chartBlue,
      'blood_glucose' => AppColors.chartOrange,
      'heart_rate' => AppColors.emergency,
      'weight' => AppColors.primary,
      'steps' => AppColors.success,
      'sleep_hours' => AppColors.chartPurple,
      _ => AppColors.textTertiary,
    };

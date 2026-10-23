import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../models/base_response.dart';
import '../../models/emergency_event_model.dart';
import '../../models/family_models.dart';
import '../../models/health_record_model.dart';
import '../../models/reminder_model.dart';
import '../../services/api_client.dart';
import '../../services/family_service.dart';
import '../../widgets/charts/chart_container.dart';
import '../../widgets/charts/health_trend_chart.dart';
import '../../widgets/common/empty_view.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/loading_view.dart';
import '../../widgets/glass_card.dart';
import '../records/health_record_history_page.dart';
import 'family_agent_page.dart';

class FamilyPatientDetailPage extends StatefulWidget {
  const FamilyPatientDetailPage({
    super.key,
    required this.patient,
    this.service,
  });

  final BoundPatientModel patient;
  final FamilyService? service;

  @override
  State<FamilyPatientDetailPage> createState() =>
      _FamilyPatientDetailPageState();
}

class _FamilyPatientDetailPageState extends State<FamilyPatientDetailPage> {
  late final FamilyService _service;
  var _records = <HealthRecordModel>[];
  var _reminders = <ReminderModel>[];
  var _sosEvents = <EmergencyEventModel>[];
  var _type = HealthRecordType.bloodPressure;
  var _range = '7d';
  FamilyHealthSummaryModel? _summary;
  HealthTrendSummary? _trend;
  var _loading = true;
  var _remindersExpanded = false;
  var _sosExpanded = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? FamilyService();
    unawaited(_loadAll());
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final summaryResponse = await _service.getFamilyHealthSummary(
        widget.patient.patientUserId,
      );
      final recordsResponse = await _service.getFamilyHealthRecords(
        patientId: widget.patient.patientUserId,
        pageSize: 20,
        type: _type,
      );
      final trendResponse = await _service.getFamilyHealthTrend(
        patientId: widget.patient.patientUserId,
        type: _type,
        range: _range,
      );
      final remindersResponse =
          await _service.getFamilyReminders(widget.patient.patientUserId);
      final sosResponse =
          await _service.getFamilySosEvents(widget.patient.patientUserId);
      if (!mounted) return;
      _throwIfFailed(summaryResponse);
      _throwIfFailed(recordsResponse);
      _throwIfFailed(trendResponse);
      _throwIfFailed(remindersResponse);
      _throwIfFailed(sosResponse);
      setState(() {
        _summary = summaryResponse.data;
        _records = [...?recordsResponse.data?.items]
          ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
        _trend = trendResponse.data;
        _reminders = [...?remindersResponse.data]
          ..sort((a, b) => b.remindAt.compareTo(a.remindAt));
        _sosEvents = [...?sosResponse.data]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage =
              error is ApiException ? error.message : error.toString();
          _loading = false;
        });
      }
    }
  }

  void _throwIfFailed(BaseResponse<Object?> response) {
    if (!response.success) {
      throw ApiException(
          response.message.isEmpty ? '家庭照护数据加载失败' : response.message);
    }
  }

  Future<void> _reloadTrend() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final recordsResponse = await _service.getFamilyHealthRecords(
        patientId: widget.patient.patientUserId,
        pageSize: 20,
        type: _type,
      );
      final trendResponse = await _service.getFamilyHealthTrend(
        patientId: widget.patient.patientUserId,
        type: _type,
        range: _range,
      );
      if (!mounted) return;
      _throwIfFailed(recordsResponse);
      _throwIfFailed(trendResponse);
      setState(() {
        _records = [...?recordsResponse.data?.items]
          ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
        _trend = trendResponse.data;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage =
              error is ApiException ? error.message : error.toString();
          _loading = false;
        });
      }
    }
  }

  void _openAgent() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FamilyAgentPage(
          patient: widget.patient,
          service: _service,
        ),
      ),
    );
  }

  void _openRecordHistory() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => HealthRecordHistoryPage(
          title: '${widget.patient.patientName}的健康记录',
          initialType: _type,
          loader: ({
            required int page,
            required int pageSize,
            required HealthRecordType type,
            DateTime? startDate,
            DateTime? endDate,
          }) =>
              _service.getFamilyHealthRecords(
            patientId: widget.patient.patientUserId,
            page: page,
            pageSize: pageSize,
            type: type,
            startDate: startDate,
            endDate: endDate,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.patient.patientName)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAll,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _PatientHeader(
                patient: widget.patient,
                summary: _summary,
                onAgent: _openAgent,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_loading)
                const SizedBox(
                    height: 420, child: LoadingView(message: '正在加载照护数据'))
              else if (_errorMessage != null)
                ErrorView(message: _errorMessage!, onRetry: _loadAll)
              else ...[
                _SummarySection(summary: _summary),
                const SizedBox(height: AppSpacing.lg),
                _TrendSection(
                  type: _type,
                  range: _range,
                  trend: _trend,
                  onTypeChanged: (value) {
                    setState(() => _type = value);
                    unawaited(_reloadTrend());
                  },
                  onRangeChanged: (value) {
                    setState(() => _range = value);
                    unawaited(_reloadTrend());
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                _RecordSection(
                  records: _records,
                  type: _type,
                  onViewAll: _openRecordHistory,
                ),
                const SizedBox(height: AppSpacing.lg),
                _ReminderSection(
                  reminders: _reminders,
                  expanded: _remindersExpanded,
                  onToggle: () => setState(
                    () => _remindersExpanded = !_remindersExpanded,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _SosSection(
                  events: _sosEvents,
                  expanded: _sosExpanded,
                  onToggle: () => setState(() => _sosExpanded = !_sosExpanded),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PatientHeader extends StatelessWidget {
  const _PatientHeader({
    required this.patient,
    required this.summary,
    required this.onAgent,
  });

  final BoundPatientModel patient;
  final FamilyHealthSummaryModel? summary;
  final VoidCallback onAgent;

  @override
  Widget build(BuildContext context) {
    final score = summary?.healthScore ?? 0;
    final color = _riskColor(patient.riskLevel);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.16),
            Colors.white,
            AppColors.blueSurface,
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(Icons.elderly_rounded, color: color, size: 30),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.patientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      summary?.status ?? _riskLabel(patient.riskLevel),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _HeaderMetric(
                  label: '健康分',
                  value: score == 0 ? '--' : '$score',
                  icon: Icons.favorite_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _HeaderMetric(
                  label: '更新时间',
                  value: _formatDate(
                      summary?.lastUpdateTime ?? patient.lastUpdateTime),
                  icon: Icons.schedule_rounded,
                  color: AppColors.chartBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: onAgent,
            icon: const Icon(Icons.smart_toy_rounded),
            label: const Text('咨询 Agent'),
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
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

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.summary});

  final FamilyHealthSummaryModel? summary;

  @override
  Widget build(BuildContext context) {
    final metrics = summary?.metrics ?? const <FamilyHealthMetricModel>[];
    return _Section(
      title: '健康摘要',
      child: metrics.isEmpty
          ? const EmptyView(title: '暂无健康摘要')
          : Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children:
                  metrics.map((metric) => _MetricChip(metric: metric)).toList(),
            ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.metric});

  final FamilyHealthMetricModel metric;

  @override
  Widget build(BuildContext context) {
    final color = switch (metric.status) {
      'danger' => AppColors.emergency,
      'warning' => AppColors.warning,
      _ => AppColors.success,
    };
    return Container(
      width: 150,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${metric.value} ${metric.unit}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _TrendSection extends StatelessWidget {
  const _TrendSection({
    required this.type,
    required this.range,
    required this.trend,
    required this.onTypeChanged,
    required this.onRangeChanged,
  });

  final HealthRecordType type;
  final String range;
  final HealthTrendSummary? trend;
  final ValueChanged<HealthRecordType> onTypeChanged;
  final ValueChanged<String> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '趋势',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        GlassCard(
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
                            value: item, child: Text(item.label));
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) onTypeChanged(value);
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
        ),
        const SizedBox(height: AppSpacing.md),
        if (trend == null || trend!.points.isEmpty)
          const GlassCard(child: EmptyView(title: '暂无趋势数据'))
        else
          ChartContainer(
            title: '${trend!.type.label}趋势',
            subtitle: trend!.range,
            child: HealthTrendChart(points: trend!.points, type: trend!.type),
          ),
      ],
    );
  }
}

class _RecordSection extends StatelessWidget {
  const _RecordSection({
    required this.records,
    required this.type,
    required this.onViewAll,
  });

  final List<HealthRecordModel> records;
  final HealthRecordType type;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final rows = records
        .take(3)
        .map(
          (record) => _InfoRow(
            icon: record.type.icon,
            color: record.type.color,
            title: record.displayValue,
            subtitle: _formatDate(record.recordedAt),
            trailing: record.status.label,
          ),
        )
        .toList();
    return _Section(
      title: '${type.label}记录',
      child: records.isEmpty
          ? const EmptyView(title: '暂无健康记录')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...rows,
                TextButton.icon(
                  onPressed: onViewAll,
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('查看全部记录'),
                ),
              ],
            ),
    );
  }
}

class _ReminderSection extends StatelessWidget {
  const _ReminderSection({
    required this.reminders,
    required this.expanded,
    required this.onToggle,
  });

  final List<ReminderModel> reminders;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return _ExpandableInfoSection(
      title: '提醒完成情况',
      emptyTitle: '暂无提醒',
      expanded: expanded,
      onToggle: onToggle,
      rows: reminders
          .map(
            (reminder) => _InfoRow(
              icon: Icons.alarm_rounded,
              color:
                  reminder.completed ? AppColors.success : AppColors.warning,
              title: reminder.title,
              subtitle: _formatDate(reminder.remindAt),
              trailing: reminder.completed ? '已完成' : '未完成',
            ),
          )
          .toList(),
    );
  }
}

class _SosSection extends StatelessWidget {
  const _SosSection({
    required this.events,
    required this.expanded,
    required this.onToggle,
  });

  final List<EmergencyEventModel> events;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return _ExpandableInfoSection(
      title: 'SOS 记录',
      emptyTitle: '暂无 SOS 记录',
      expanded: expanded,
      onToggle: onToggle,
      rows: events
          .map(
            (event) => _InfoRow(
              icon: Icons.sos_rounded,
              color: AppColors.emergency,
              title: event.message?.trim().isNotEmpty == true
                  ? event.message!
                  : 'SOS 事件',
              subtitle: _formatDate(event.createdAt),
              trailing: event.status ?? '',
            ),
          )
          .toList(),
    );
  }
}

class _ExpandableInfoSection extends StatelessWidget {
  const _ExpandableInfoSection({
    required this.title,
    required this.emptyTitle,
    required this.rows,
    required this.expanded,
    required this.onToggle,
  });

  final String title;
  final String emptyTitle;
  final List<Widget> rows;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final visibleRows = expanded ? rows : rows.take(3).toList();
    return _Section(
      title: title,
      child: rows.isEmpty
          ? EmptyView(title: emptyTitle)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...visibleRows,
                if (rows.length > 3)
                  TextButton.icon(
                    key: ValueKey(
                      'expandable_${title}_${expanded ? 'collapse' : 'expand'}',
                    ),
                    onPressed: onToggle,
                    icon: Icon(
                      expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                    ),
                    label: Text(
                      expanded ? '收起' : '查看全部 ${rows.length} 条',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            trailing,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

Color _riskColor(String riskLevel) {
  return switch (riskLevel) {
    'high' => AppColors.emergency,
    'medium' => AppColors.warning,
    'low' => AppColors.success,
    _ => AppColors.textTertiary,
  };
}

String _riskLabel(String riskLevel) {
  return switch (riskLevel) {
    'high' => '存在高风险指标',
    'medium' => '部分指标需关注',
    'low' => '近期状态平稳',
    _ => '暂无健康记录',
  };
}

String _formatDate(DateTime? time) {
  if (time == null) return '暂无';
  return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

extension _FamilyRecordTypeStyle on HealthRecordType {
  IconData get icon => switch (this) {
        HealthRecordType.bloodPressure => Icons.water_drop_rounded,
        HealthRecordType.bloodSugar => Icons.bloodtype_rounded,
        HealthRecordType.heartRate => Icons.favorite_rounded,
        HealthRecordType.weight => Icons.monitor_weight_rounded,
        HealthRecordType.other => Icons.add_chart_rounded,
      };

  Color get color => switch (this) {
        HealthRecordType.bloodPressure => AppColors.chartBlue,
        HealthRecordType.bloodSugar => AppColors.chartOrange,
        HealthRecordType.heartRate => AppColors.emergency,
        HealthRecordType.weight => AppColors.primary,
        HealthRecordType.other => AppColors.chartPurple,
      };
}

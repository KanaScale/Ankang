import 'package:flutter/material.dart';

import '../../app/app_runtime_settings.dart';
import '../../app/design_tokens.dart';
import '../../models/health_event_model.dart';
import '../../models/health_record_model.dart';
import '../../pages/emergency/emergency_page.dart';
import '../../routes/route_names.dart';
import '../../services/health_event_service.dart';
import '../../services/record_service.dart';
import '../../utils/date_util.dart';
import '../../utils/toast_util.dart';
import '../../widgets/common/empty_view.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/loading_view.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/health_risk_dialog.dart';
import '../../widgets/ios_bottom_navigation.dart';
import 'health_record_history_page.dart';
import 'record_form_page.dart';
import 'trend_page.dart';

class RecordListPage extends StatefulWidget {
  const RecordListPage({
    super.key,
    this.recordService,
    this.healthEventService,
  });

  final RecordService? recordService;
  final HealthEventService? healthEventService;

  @override
  State<RecordListPage> createState() => _RecordListPageState();
}

class _RecordListPageState extends State<RecordListPage> {
  static const _pageSize = 10;

  late final RecordService _recordService;
  late final HealthEventService _healthEventService;
  var _records = <HealthRecordModel>[];
  var _selectedType = HealthRecordType.bloodPressure;
  var _loading = true;
  var _loadingMore = false;
  var _hasMore = true;
  var _currentPage = 1;
  var _loadGeneration = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _recordService = widget.recordService ?? RecordService();
    _healthEventService = widget.healthEventService ?? HealthEventService();
    _loadRecords();
  }

  Future<void> _loadRecords({bool loadMore = false}) async {
    if (loadMore && (_loading || _loadingMore || !_hasMore)) return;

    final generation = loadMore ? _loadGeneration : ++_loadGeneration;
    final requestedType = _selectedType;
    final requestedPage = loadMore ? _currentPage + 1 : 1;
    setState(() {
      if (loadMore) {
        _loadingMore = true;
      } else {
        _loading = true;
        _currentPage = 1;
        _hasMore = true;
        _error = null;
      }
    });

    try {
      final response = await _recordService.getRecords(
        type: requestedType,
        page: requestedPage,
        pageSize: _pageSize,
      );
      if (!mounted ||
          generation != _loadGeneration ||
          requestedType != _selectedType) {
        return;
      }
      final page = response.data;
      final incoming = page?.items ?? const <HealthRecordModel>[];
      setState(() {
        if (loadMore) {
          final existingIds = _records.map((record) => record.id).toSet();
          _records = [
            ..._records,
            ...incoming.where((record) => existingIds.add(record.id)),
          ];
          _currentPage = requestedPage;
        } else {
          _records = page == null ? _sampleRecords(requestedType) : incoming;
          _currentPage = 1;
        }
        _hasMore =
            page != null && incoming.isNotEmpty && _records.length < page.total;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        if (loadMore) {
          _error = '历史记录加载失败，请稍后重试';
          _loadingMore = false;
        } else {
          _records = _sampleRecords(requestedType);
          _error = '后端暂不可用，当前展示演示数据';
          _loading = false;
          _hasMore = false;
        }
      });
    }
  }

  Future<void> _openForm() async {
    final created = await Navigator.of(context).push<HealthRecordModel>(
      MaterialPageRoute(
        builder: (_) => RecordFormPage(
          initialType: _selectedType,
          recordService: _recordService,
        ),
      ),
    );
    if (created == null || !mounted) {
      return;
    }
    setState(() {
      _selectedType = created.type;
      _records = [
        created,
        ..._records.where((record) => record.id != created.id),
      ].take(_pageSize).toList(growable: false);
      _currentPage = 1;
      _hasMore = true;
    });
    await _showRiskFeedback(created);
  }

  Future<void> _deleteRecord(HealthRecordModel record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除健康记录'),
        content: Text('确定要删除这条${record.type.label}记录吗？删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.emergency,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    try {
      final response = await _recordService.deleteRecord(record.id);
      if (!mounted) {
        return;
      }
      if (!response.success) {
        ToastUtil.show(
          context,
          response.message.isEmpty ? '删除失败，请稍后重试' : response.message,
        );
        return;
      }
      setState(() {
        _records = _records
            .where((existing) => existing.id != record.id)
            .toList(growable: false);
      });
      ToastUtil.show(context, '健康记录已删除');
    } catch (_) {
      if (mounted) {
        ToastUtil.show(context, '删除失败，请稍后重试');
      }
    }
  }

  Future<void> _showRiskFeedback(HealthRecordModel record) async {
    if (record.id <= 0) return;
    HealthEventModel? event;
    try {
      event = await _healthEventService.waitForRecordEvent(record.id);
    } catch (_) {
      // 风险提示失败不能回滚或隐藏已经成功保存的健康记录。
      return;
    }
    if (!mounted || event == null || !event.needsAttention) return;

    final action = await showHealthRiskDialog(context, event);
    if (!mounted || action == null || action == HealthRiskAction.later) return;

    final Widget page;
    if (action == HealthRiskAction.trend) {
      page = TrendPage(initialType: record.type);
    } else if (action == HealthRiskAction.sos) {
      page = const EmergencyPage();
    } else {
      return;
    }
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  void _openTrend() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TrendPage(initialType: _selectedType),
      ),
    );
  }

  void _openHistory() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => HealthRecordHistoryPage(
          title: '全部健康记录',
          initialType: _selectedType,
          loader: ({
            required int page,
            required int pageSize,
            required HealthRecordType type,
            DateTime? startDate,
            DateTime? endDate,
          }) =>
              _recordService.getRecords(
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
    return AnimatedBuilder(
      animation: AppRuntimeSettings.instance,
      builder: (context, _) {
        final settings = AppRuntimeSettings.instance;
        final simpleMode = settings.simpleMode;
        final visibleRecords = _records.take(3);
        return Scaffold(
          extendBody: true,
          backgroundColor: AppColors.background,
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: _loadRecords,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  18,
                  simpleMode ? 12 : 18,
                  18,
                  simpleMode ? 98 : 112,
                ),
                children: [
                  _HealthHero(
                    selectedType: _selectedType,
                    records: _records,
                    compact: simpleMode,
                    onAdd: _openForm,
                    onTrend: _openTrend,
                  ),
                  SizedBox(height: simpleMode ? AppSpacing.md : AppSpacing.lg),
                  _TypeFilter(
                    selectedType: _selectedType,
                    compact: simpleMode,
                    onChanged: (type) {
                      setState(() => _selectedType = type);
                      _loadRecords();
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_error != null) _DemoNotice(message: _error!),
                  if (_error != null) const SizedBox(height: AppSpacing.md),
                  if (!simpleMode) ...[
                    _SummaryStrip(records: _records),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  _SectionHeader(
                    title: simpleMode ? '最近记录' : '${_selectedType.label}记录',
                    actionLabel: '趋势',
                    showAction: !simpleMode,
                    onAction: _openTrend,
                    onAdd: _openForm,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (_loading)
                    const SizedBox(height: 320, child: LoadingView())
                  else if (_records.isEmpty)
                    EmptyView(
                      title: '暂无健康记录',
                      message: '点击右上角加号录入第一条${_selectedType.label}数据。',
                    )
                  else ...[
                    ...visibleRecords.map(
                      (record) => _RecordTile(
                        record: record,
                        compact: simpleMode,
                        onDelete: () => _deleteRecord(record),
                      ),
                    ),
                    TextButton.icon(
                      key: const ValueKey('patient_view_all_records'),
                      onPressed: _openHistory,
                      icon: const Icon(Icons.history_rounded),
                      label: const Text('查看全部记录'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          bottomNavigationBar:
              const IosBottomNavigation(currentRoute: RouteNames.health),
        );
      },
    );
  }

  List<HealthRecordModel> _sampleRecords(HealthRecordType type) {
    final now = DateTime.now();
    return switch (type) {
      HealthRecordType.bloodPressure => [
          HealthRecordModel(
            id: 1001,
            type: type,
            value: 128,
            systolic: 128,
            diastolic: 82,
            unit: type.defaultUnit,
            status: HealthRecordStatus.normal,
            recordedAt: now.subtract(const Duration(hours: 2)),
            remark: '早餐前测量',
          ),
          HealthRecordModel(
            id: 1002,
            type: type,
            value: 142,
            systolic: 142,
            diastolic: 91,
            unit: type.defaultUnit,
            status: HealthRecordStatus.warning,
            recordedAt: now.subtract(const Duration(days: 1, hours: 1)),
            remark: '晚饭后复测',
          ),
        ],
      HealthRecordType.bloodSugar => [
          HealthRecordModel(
            id: 2001,
            type: type,
            value: 5.8,
            unit: type.defaultUnit,
            status: HealthRecordStatus.normal,
            recordedAt: now.subtract(const Duration(hours: 3)),
            remark: '空腹',
          ),
          HealthRecordModel(
            id: 2002,
            type: type,
            value: 7.4,
            unit: type.defaultUnit,
            status: HealthRecordStatus.warning,
            recordedAt: now.subtract(const Duration(days: 1)),
            remark: '餐后两小时',
          ),
        ],
      HealthRecordType.heartRate => [
          HealthRecordModel(
            id: 3001,
            type: type,
            value: 72,
            unit: type.defaultUnit,
            status: HealthRecordStatus.normal,
            recordedAt: now.subtract(const Duration(hours: 1)),
            remark: '静息心率',
          ),
          HealthRecordModel(
            id: 3002,
            type: type,
            value: 86,
            unit: type.defaultUnit,
            status: HealthRecordStatus.normal,
            recordedAt: now.subtract(const Duration(days: 1)),
            remark: '散步后',
          ),
        ],
      HealthRecordType.weight => [
          HealthRecordModel(
            id: 4001,
            type: type,
            value: 65.5,
            unit: type.defaultUnit,
            status: HealthRecordStatus.normal,
            recordedAt: now.subtract(const Duration(days: 1)),
            remark: '晨起空腹',
          ),
        ],
      HealthRecordType.other => const [],
    };
  }
}

class _HealthHero extends StatelessWidget {
  const _HealthHero({
    required this.selectedType,
    required this.records,
    required this.compact,
    required this.onAdd,
    required this.onTrend,
  });

  final HealthRecordType selectedType;
  final List<HealthRecordModel> records;
  final bool compact;
  final VoidCallback onAdd;
  final VoidCallback onTrend;

  @override
  Widget build(BuildContext context) {
    final latest = records.isEmpty ? null : records.first;
    final color = selectedType.accentColor;
    return Container(
      padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.22),
            Colors.white,
            AppColors.greenSurface,
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
                width: compact ? 46 : 54,
                height: compact ? 46 : 54,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(selectedType.icon, color: color, size: 28),
              ),
              const Spacer(),
              if (!compact) ...[
                IconButton.filledTonal(
                  tooltip: '趋势分析',
                  onPressed: onTrend,
                  icon: const Icon(Icons.show_chart_rounded),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              IconButton.filled(
                tooltip: '新增记录',
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          SizedBox(height: compact ? AppSpacing.md : AppSpacing.xl),
          Text(
            '健康数据',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            latest == null
                ? '开始记录${selectedType.label}，建立自己的健康趋势。'
                : '最近一次${selectedType.label}：${latest.displayValue}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _TypeFilter extends StatelessWidget {
  const _TypeFilter({
    required this.selectedType,
    required this.compact,
    required this.onChanged,
  });

  final HealthRecordType selectedType;
  final bool compact;
  final ValueChanged<HealthRecordType> onChanged;

  static const types = [
    HealthRecordType.bloodPressure,
    HealthRecordType.bloodSugar,
    HealthRecordType.heartRate,
    HealthRecordType.weight,
  ];

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: types.map((type) {
            final selected = type == selectedType;
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: _CompactTypeChip(
                type: type,
                selected: selected,
                onTap: () => onChanged(type),
              ),
            );
          }).toList(),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = constraints.maxWidth >= 600
            ? 4
            : constraints.maxWidth >= 280
                ? 2
                : 1;
        final spacing = AppSpacing.sm * (columnCount - 1);
        final itemWidth = (constraints.maxWidth - spacing) / columnCount;

        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: types.map((type) {
            final selected = type == selectedType;
            return SizedBox(
              width: itemWidth,
              height: 92,
              child: _TypePill(
                type: type,
                selected: selected,
                onTap: () => onChanged(type),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _CompactTypeChip extends StatelessWidget {
  const _CompactTypeChip({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final HealthRecordType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = type.accentColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.16) : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color:
                  selected ? color.withValues(alpha: 0.32) : AppColors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: selected ? 0.18 : 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(type.icon, color: color, size: 16),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                type.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: selected ? color : AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final HealthRecordType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = type.accentColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.14) : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected ? AppShadows.subtle : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(type.icon, color: color, size: 24),
              const SizedBox(height: AppSpacing.sm),
              Text(
                type.label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: selected ? color : AppColors.textPrimary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.records});

  final List<HealthRecordModel> records;

  @override
  Widget build(BuildContext context) {
    final warningCount = records
        .where((record) => record.status != HealthRecordStatus.normal)
        .length;
    final latest = records.isEmpty ? '--' : records.first.displayValue;
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: '最新记录',
            value: latest,
            icon: Icons.monitor_heart_rounded,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _SummaryCard(
            label: '已加载异常',
            value: '$warningCount',
            icon: Icons.warning_amber_rounded,
            color: warningCount > 0 ? AppColors.warning : AppColors.primary,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.primary,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.showAction,
    required this.onAction,
    required this.onAdd,
  });

  final String title;
  final String actionLabel;
  final bool showAction;
  final VoidCallback onAction;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        if (showAction) ...[
          TextButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.show_chart_rounded, size: 18),
            label: Text(actionLabel),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        TextButton.icon(
          key: const ValueKey('patient_add_record'),
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('新增数据'),
        ),
      ],
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.record,
    required this.compact,
    required this.onDelete,
  });

  final HealthRecordModel record;
  final bool compact;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = switch (record.status) {
      HealthRecordStatus.normal => AppColors.primary,
      HealthRecordStatus.warning => AppColors.warning,
      HealthRecordStatus.danger => AppColors.emergency,
    };
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final useLargeTextLayout =
        textScale >= 1 || MediaQuery.sizeOf(context).width < 360;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: GlassCard(
        padding: EdgeInsets.zero,
        borderRadius: AppRadius.lg,
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(AppRadius.lg),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding:
                      EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
                  child: useLargeTextLayout
                      ? _buildLargeTextLayout(context, color)
                      : _buildDefaultLayout(context, color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultLayout(BuildContext context, Color color) {
    return Row(
      children: [
        _RecordTypeIcon(record: record, compact: compact, color: color),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _RecordTitle(record: record)),
                  _StatusBadge(record: record, color: color),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              _RecordTimestamp(record: record),
              if (!compact && record.remark?.isNotEmpty == true) ...[
                const SizedBox(height: AppSpacing.xs),
                _RecordRemark(record: record),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _RecordValue(record: record),
        _RecordDeleteButton(recordId: record.id, onDelete: onDelete),
      ],
    );
  }

  Widget _buildLargeTextLayout(BuildContext context, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _RecordTypeIcon(record: record, compact: compact, color: color),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RecordTitle(record: record),
              const SizedBox(height: AppSpacing.xs),
              _RecordTimestamp(record: record),
              if (!compact && record.remark?.isNotEmpty == true) ...[
                const SizedBox(height: AppSpacing.xs),
                _RecordRemark(record: record),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _StatusBadge(record: record, color: color),
                const SizedBox(height: AppSpacing.sm),
                _RecordValue(record: record),
              ],
            ),
            _RecordDeleteButton(recordId: record.id, onDelete: onDelete),
          ],
        ),
      ],
    );
  }
}

class _RecordTypeIcon extends StatelessWidget {
  const _RecordTypeIcon({
    required this.record,
    required this.compact,
    required this.color,
  });

  final HealthRecordModel record;
  final bool compact;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: compact ? 20 : 24,
      backgroundColor: color.withValues(alpha: 0.14),
      foregroundColor: color,
      child: Icon(record.type.icon),
    );
  }
}

class _RecordTitle extends StatelessWidget {
  const _RecordTitle({required this.record});

  final HealthRecordModel record;

  @override
  Widget build(BuildContext context) {
    return Text(
      record.title,
      key: ValueKey('record_title_${record.id}'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

class _RecordValue extends StatelessWidget {
  const _RecordValue({required this.record});

  final HealthRecordModel record;

  @override
  Widget build(BuildContext context) {
    return Text(
      record.displayValue,
      key: ValueKey('record_value_${record.id}'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.right,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
    );
  }
}

class _RecordTimestamp extends StatelessWidget {
  const _RecordTimestamp({required this.record});

  final HealthRecordModel record;

  @override
  Widget build(BuildContext context) {
    return Text(
      DateUtil.formatDateTime(record.recordedAt),
      style: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(color: AppColors.textTertiary),
    );
  }
}

class _RecordRemark extends StatelessWidget {
  const _RecordRemark({required this.record});

  final HealthRecordModel record;

  @override
  Widget build(BuildContext context) {
    return Text(
      record.remark!,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _RecordDeleteButton extends StatelessWidget {
  const _RecordDeleteButton({
    required this.recordId,
    required this.onDelete,
  });

  final int recordId;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: ValueKey('record_delete_$recordId'),
      onPressed: onDelete,
      tooltip: '删除记录',
      color: AppColors.emergency,
      icon: const Icon(Icons.delete_outline_rounded),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.record,
    required this.color,
  });

  final HealthRecordModel record;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        record.status.label,
        key: ValueKey('record_status_${record.id}'),
        maxLines: 1,
        softWrap: false,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ErrorView(
      message: message,
      onRetry: () {},
    );
  }
}

extension _HealthRecordTypeStyle on HealthRecordType {
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

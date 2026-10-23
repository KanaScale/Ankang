import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../models/base_response.dart';
import '../../models/health_record_model.dart';
import '../../utils/date_util.dart';
import '../../widgets/common/empty_view.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/loading_view.dart';
import '../../widgets/glass_card.dart';

typedef HealthRecordPageLoader = Future<
    BaseResponse<PageResult<HealthRecordModel>>> Function({
  required int page,
  required int pageSize,
  required HealthRecordType type,
  DateTime? startDate,
  DateTime? endDate,
});

class HealthRecordHistoryPage extends StatefulWidget {
  const HealthRecordHistoryPage({
    super.key,
    required this.title,
    required this.loader,
    required this.initialType,
  });

  final String title;
  final HealthRecordPageLoader loader;
  final HealthRecordType initialType;

  @override
  State<HealthRecordHistoryPage> createState() =>
      _HealthRecordHistoryPageState();
}

class _HealthRecordHistoryPageState extends State<HealthRecordHistoryPage> {
  static const _pageSize = 20;

  final _scrollController = ScrollController();
  var _records = <HealthRecordModel>[];
  late HealthRecordType _type;
  DateTime? _startDate;
  DateTime? _endDate;
  var _page = 1;
  var _total = 0;
  var _loading = true;
  var _loadingMore = false;
  var _hasMore = true;
  var _generation = 0;
  String? _initialError;
  String? _moreError;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _scrollController.addListener(_handleScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_scrollController.position.extentAfter < 240) {
      _load(loadMore: true);
    }
  }

  Future<void> _load({bool loadMore = false}) async {
    if (loadMore && (_loading || _loadingMore || !_hasMore)) return;
    final generation = loadMore ? _generation : ++_generation;
    final requestedPage = loadMore ? _page + 1 : 1;
    setState(() {
      if (loadMore) {
        _loadingMore = true;
        _moreError = null;
      } else {
        _loading = true;
        _initialError = null;
        _moreError = null;
        _hasMore = true;
      }
    });
    try {
      final response = await widget.loader(
        page: requestedPage,
        pageSize: _pageSize,
        type: _type,
        startDate: _startDate,
        endDate: _endDate,
      );
      if (!mounted || generation != _generation) return;
      if (!response.success || response.data == null) {
        throw Exception(
          response.message.isEmpty ? '健康记录加载失败' : response.message,
        );
      }
      final result = response.data!;
      final incoming = result.items;
      setState(() {
        if (loadMore) {
          final ids = _records.map((item) => item.id).toSet();
          _records = [
            ..._records,
            ...incoming.where((item) => ids.add(item.id)),
          ];
        } else {
          _records = [...incoming];
        }
        _records.sort((a, b) {
          final timeOrder = b.recordedAt.compareTo(a.recordedAt);
          return timeOrder != 0 ? timeOrder : b.id.compareTo(a.id);
        });
        _page = requestedPage;
        _total = result.total;
        _hasMore = incoming.isNotEmpty && _records.length < result.total;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        if (loadMore) {
          _moreError = error.toString();
          _loadingMore = false;
        } else {
          _records = [];
          _initialError = error.toString();
          _loading = false;
          _hasMore = false;
        }
      });
    }
  }

  Future<void> _pickDate({required bool start}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: (start ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (start) {
        _startDate = selected;
        if (_endDate != null && selected.isAfter(_endDate!)) {
          _endDate = selected;
        }
      } else {
        _endDate = selected;
        if (_startDate != null && selected.isBefore(_startDate!)) {
          _startDate = selected;
        }
      }
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _HistoryFilters(
                type: _type,
                startDate: _startDate,
                endDate: _endDate,
                onTypeChanged: (value) {
                  setState(() => _type = value);
                  _load();
                },
                onStartDate: () => _pickDate(start: true),
                onEndDate: () => _pickDate(start: false),
                onClearDates: _startDate == null && _endDate == null
                    ? null
                    : () {
                        setState(() {
                          _startDate = null;
                          _endDate = null;
                        });
                        _load();
                      },
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '已加载 ${_records.length}/$_total 条',
                key: const ValueKey('health_history_progress'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_loading)
                const SizedBox(height: 360, child: LoadingView())
              else if (_initialError != null)
                ErrorView(message: _initialError!, onRetry: _load)
              else if (_records.isEmpty)
                const EmptyView(title: '暂无符合条件的健康记录')
              else ...[
                ..._records.map((record) => _HistoryRecordTile(record: record)),
                if (_loadingMore)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_moreError != null)
                  OutlinedButton.icon(
                    onPressed: () => _load(loadMore: true),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('重试加载更多'),
                  )
                else if (!_hasMore)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Center(
                      child: Text(
                        '已加载全部历史记录',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textTertiary,
                            ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryFilters extends StatelessWidget {
  const _HistoryFilters({
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.onTypeChanged,
    required this.onStartDate,
    required this.onEndDate,
    required this.onClearDates,
  });

  final HealthRecordType type;
  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<HealthRecordType> onTypeChanged;
  final VoidCallback onStartDate;
  final VoidCallback onEndDate;
  final VoidCallback? onClearDates;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          DropdownButtonFormField<HealthRecordType>(
            initialValue: type,
            decoration: const InputDecoration(
              labelText: '健康指标',
              prefixIcon: Icon(Icons.monitor_heart_rounded),
            ),
            items: const [
              HealthRecordType.bloodPressure,
              HealthRecordType.bloodSugar,
              HealthRecordType.heartRate,
              HealthRecordType.weight,
            ]
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(item.label),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onTypeChanged(value);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final vertical =
                  MediaQuery.textScalerOf(context).scale(1) > 1.15 ||
                      constraints.maxWidth < 300;
              final start = OutlinedButton.icon(
                onPressed: onStartDate,
                icon: const Icon(Icons.date_range_rounded),
                label: Text(_dateLabel(startDate, '开始日期')),
              );
              final end = OutlinedButton.icon(
                onPressed: onEndDate,
                icon: const Icon(Icons.event_rounded),
                label: Text(_dateLabel(endDate, '结束日期')),
              );
              return vertical
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        start,
                        const SizedBox(height: AppSpacing.sm),
                        end,
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: start),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: end),
                      ],
                    );
            },
          ),
          if (onClearDates != null)
            TextButton(
              onPressed: onClearDates,
              child: const Text('清除日期筛选'),
            ),
        ],
      ),
    );
  }

  String _dateLabel(DateTime? value, String fallback) {
    if (value == null) return fallback;
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}

class _HistoryRecordTile extends StatelessWidget {
  const _HistoryRecordTile({required this.record});

  final HealthRecordModel record;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: GlassCard(
        child: Row(
          children: [
            const Icon(Icons.monitor_heart_rounded, color: AppColors.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.displayValue,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    DateUtil.formatDateTime(record.recordedAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                  ),
                ],
              ),
            ),
            Text(record.status.label),
          ],
        ),
      ),
    );
  }
}

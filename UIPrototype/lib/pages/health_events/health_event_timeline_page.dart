import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/design_tokens.dart';
import '../../models/health_event_model.dart';
import '../../services/health_event_service.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/loading_view.dart';

class HealthEventTimelinePage extends StatefulWidget {
  const HealthEventTimelinePage({
    super.key,
    required this.event,
    this.service,
  });

  final HealthEventModel event;
  final HealthEventService? service;

  @override
  State<HealthEventTimelinePage> createState() =>
      _HealthEventTimelinePageState();
}

class _HealthEventTimelinePageState extends State<HealthEventTimelinePage> {
  late final HealthEventService _service;
  HealthEventModel? _event;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? HealthEventService();
    _event = widget.event.timeline.isEmpty ? null : widget.event;
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _error = null);
    try {
      final response = await _service.getEventDetail(widget.event.eventId);
      if (!mounted) return;
      setState(() => _event = response.data ?? widget.event);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _event ??= widget.event;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('事件处理时间线')),
      body: SafeArea(
        child: event == null
            ? const LoadingView()
            : RefreshIndicator(
                onRefresh: _loadDetail,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    _EventSummaryCard(event: event),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      ErrorView(message: '刷新失败：$_error', onRetry: _loadDetail),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      '处理记录',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (event.timeline.isEmpty)
                      const _EmptyTimeline()
                    else
                      ...List.generate(
                        event.timeline.length,
                        (index) => _TimelineItem(
                          item: event.timeline[index],
                          isLast: index == event.timeline.length - 1,
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _EventSummaryCard extends StatelessWidget {
  const _EventSummaryCard({required this.event});

  final HealthEventModel event;

  @override
  Widget build(BuildContext context) {
    final high = event.riskLevel == HealthRiskLevel.high;
    final color = high ? AppColors.emergency : AppColors.warning;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.14),
                foregroundColor: color,
                child: const Icon(Icons.monitor_heart_rounded),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${event.riskLevel.label} · ${event.riskScore} 分',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    Text(
                      event.status == 'completed' ? '处理完成' : event.status,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(event.summary),
          if (event.sosEventId != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '已关联 SOS 预案 #${event.sosEventId}（尚未发送真实通知）',
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.item, required this.isLast});

  final HealthEventTimelineModel item;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final completed = item.stage == 'completed';
    final failed = item.stage == 'failed';
    final color = failed
        ? AppColors.emergency
        : completed
            ? AppColors.success
            : AppColors.chartBlue;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                  child: const Icon(Icons.check, size: 12, color: Colors.white),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                        width: 2, color: color.withValues(alpha: 0.3)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _stageLabel(item.stage),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(item.message),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    DateFormat('HH:mm:ss').format(item.occurredAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
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

  String _stageLabel(String stage) => switch (stage) {
        'received' => '健康数据已保存',
        'published' => '事件已发布',
        'assessing' => '风险评估中',
        'alerted' => '风险预警已生成',
        'sos_prepared' => 'SOS 预案已创建',
        'pushed' => '结果已推送',
        'completed' => '处理完成',
        'failed' => '处理失败',
        _ => stage,
      };
}

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: const Text('暂未取得处理时间线，下拉即可重新加载。'),
    );
  }
}

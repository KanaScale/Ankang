import 'package:flutter/material.dart';

import '../app/design_tokens.dart';
import '../models/agent_action.dart';

typedef AgentActionSubmit = Future<AgentActionModel?> Function(
  AgentActionModel action,
  bool confirmed,
);

class AgentActionCard extends StatefulWidget {
  const AgentActionCard({
    super.key,
    required this.action,
    required this.onSubmit,
  });

  final AgentActionModel action;
  final AgentActionSubmit onSubmit;

  @override
  State<AgentActionCard> createState() => _AgentActionCardState();
}

class _AgentActionCardState extends State<AgentActionCard> {
  AgentActionModel? _result;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final current = _result ?? widget.action;
    final executed = current.status == 'EXECUTED';
    final failed = current.status == 'FAILED';
    final cancelled = current.status == 'CANCELLED';
    final accent = failed || cancelled
        ? AppColors.textTertiary
        : executed
            ? AppColors.success
            : _actionColor(widget.action.actionType);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_actionIcon(widget.action.actionType), color: accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.action.title.isEmpty
                          ? _actionTitle(widget.action.actionType)
                          : widget.action.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    if (widget.action.description.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        widget.action.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _PayloadSummary(payload: widget.action.payload),
          if (current.resultMessage.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              current.resultMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
          _ActionResultDetails(action: current),
          if (_result == null && widget.action.pending) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _submitting ? null : () => _submit(false),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('取消'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : () => _submit(true),
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_confirmIcon(widget.action.actionType)),
                    label: Text(_confirmLabel(widget.action.actionType)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _submit(bool confirmed) async {
    setState(() => _submitting = true);
    try {
      final result = await widget.onSubmit(widget.action, confirmed);
      if (mounted && result != null) {
        setState(() => _result = result);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Color _actionColor(String type) {
    if (type.contains('SOS')) return AppColors.emergency;
    if (type.contains('RISK')) return AppColors.warning;
    return AppColors.primary;
  }

  IconData _actionIcon(String type) {
    if (type == 'RECORD_HEALTH_DATA') return Icons.monitor_heart_rounded;
    if (type == 'CREATE_HEALTH_PLAN') return Icons.event_available_rounded;
    if (type == 'EVALUATE_HEALTH_RISK') return Icons.warning_amber_rounded;
    if (type == 'PREPARE_SOS_PLAN') return Icons.sos_rounded;
    if (type == 'SEARCH_NEARBY_HOSPITALS') return Icons.local_hospital_rounded;
    if (type == 'NOTIFY_FAMILY_PREVIEW') return Icons.family_restroom_rounded;
    return Icons.task_alt_rounded;
  }

  IconData _confirmIcon(String type) {
    if (type == 'PREPARE_SOS_PLAN') return Icons.health_and_safety_rounded;
    if (type == 'NOTIFY_FAMILY_PREVIEW') return Icons.preview_rounded;
    return Icons.check_rounded;
  }

  String _confirmLabel(String type) {
    if (type == 'RECORD_HEALTH_DATA') return '确认录入';
    if (type == 'CREATE_HEALTH_PLAN') return '确认创建';
    if (type == 'PREPARE_SOS_PLAN') return '生成预案';
    if (type == 'NOTIFY_FAMILY_PREVIEW') return '生成预览';
    return '确认执行';
  }

  String _actionTitle(String type) {
    if (type == 'RECORD_HEALTH_DATA') return '健康数据录入';
    if (type == 'CREATE_HEALTH_PLAN') return '健康计划';
    if (type == 'EVALUATE_HEALTH_RISK') return '风险评估';
    if (type == 'PREPARE_SOS_PLAN') return 'SOS 预案';
    if (type == 'SEARCH_NEARBY_HOSPITALS') return '附近医院';
    if (type == 'NOTIFY_FAMILY_PREVIEW') return '通知家属预览';
    return 'Agent Action';
  }
}

class _PayloadSummary extends StatelessWidget {
  const _PayloadSummary({required this.payload});

  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    final items = _items();
    if (items.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: items
          .map(
            (item) => Chip(
              label: Text(item),
              visualDensity: VisualDensity.compact,
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.border),
            ),
          )
          .toList(),
    );
  }

  List<String> _items() {
    final items = <String>[];
    final systolic = payload['systolic'];
    final diastolic = payload['diastolic'];
    if (systolic != null && diastolic != null) {
      items.add('血压 $systolic/$diastolic');
    }
    if (payload['heartRate'] != null) items.add('心率 ${payload['heartRate']}');
    if (payload['bloodGlucose'] != null) {
      items.add('血糖 ${payload['bloodGlucose']}');
    }
    if (payload['weight'] != null) items.add('体重 ${payload['weight']}kg');
    if (payload['recordedAt'] != null) items.add('${payload['recordedAt']}');
    final reminders = payload['reminders'] as List<dynamic>? ?? const [];
    for (final item in reminders.whereType<Map<String, dynamic>>()) {
      final title = item['title'] as String? ?? '';
      final time = item['remindTime'] as String? ?? '';
      if (title.isNotEmpty && time.isNotEmpty) items.add('$time $title');
    }
    return items;
  }
}

class _ActionResultDetails extends StatelessWidget {
  const _ActionResultDetails({required this.action});

  final AgentActionModel action;

  @override
  Widget build(BuildContext context) {
    final risk = action.risk;
    final hospitals = action.nearbyHospitals;
    final familyContacts = action.familyContacts;
    final emergencyContacts = action.emergencyContacts;
    final messagePreview = action.result['messagePreview'] as String? ??
        action.result['recommendedMessage'] as String?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (risk != null) _RiskSummary(risk: risk),
        if (hospitals.isNotEmpty)
          _SectionList(
            icon: Icons.local_hospital_rounded,
            title: '附近医院',
            items: hospitals
                .take(3)
                .map((item) => '${item.name} ${item.distance}'.trim())
                .toList(),
          ),
        if (familyContacts.isNotEmpty)
          _SectionList(
            icon: Icons.family_restroom_rounded,
            title: '拟通知家属',
            items: familyContacts
                .map((item) => '${item.name} ${item.relationship}'.trim())
                .toList(),
          ),
        if (emergencyContacts.isNotEmpty)
          _SectionList(
            icon: Icons.contact_phone_rounded,
            title: '紧急联系人',
            items: emergencyContacts
                .map((item) => '${item.name} ${item.relationship}'.trim())
                .toList(),
          ),
        if (messagePreview != null && messagePreview.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            messagePreview,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ],
    );
  }
}

class _RiskSummary extends StatelessWidget {
  const _RiskSummary({required this.risk});

  final AgentRiskModel risk;

  @override
  Widget build(BuildContext context) {
    final high = risk.riskLevel == 'high';
    final color = high ? AppColors.emergency : AppColors.warning;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${high ? '高风险' : '风险提示'} · ${risk.riskScore} 分',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
          ),
          if (risk.summary.isNotEmpty) Text(risk.summary),
          ...risk.reasons.take(3).map(
                (item) => Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxs),
                  child: Text('· $item'),
                ),
              ),
        ],
      ),
    );
  }
}

class _SectionList extends StatelessWidget {
  const _SectionList({
    required this.icon,
    required this.title,
    required this.items,
  });

  final IconData icon;
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          ...items.map((item) => Text('· $item')),
        ],
      ),
    );
  }
}

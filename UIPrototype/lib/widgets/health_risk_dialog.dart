import 'package:flutter/material.dart';

import '../app/design_tokens.dart';
import '../models/health_event_model.dart';

enum HealthRiskAction { trend, sos, later }

Future<HealthRiskAction?> showHealthRiskDialog(
  BuildContext context,
  HealthEventModel event,
) {
  return showDialog<HealthRiskAction>(
    context: context,
    barrierDismissible: false,
    builder: (_) => HealthRiskDialog(event: event),
  );
}

class HealthRiskDialog extends StatelessWidget {
  const HealthRiskDialog({super.key, required this.event});

  final HealthEventModel event;

  @override
  Widget build(BuildContext context) {
    final high = event.riskLevel == HealthRiskLevel.high;
    final accent = high ? AppColors.emergency : AppColors.warning;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: accent.withValues(alpha: 0.18),
              foregroundColor: accent,
              child: Icon(high ? Icons.warning_rounded : Icons.monitor_heart),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(high ? '检测到较高健康风险' : '检测到健康指标异常'),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '${event.riskLevel.label} · ${event.riskScore} 分',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                event.summary.isEmpty ? '请关注本次健康数据变化。' : event.summary,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '风险原因',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ...event.reasons.map(
                (reason) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(reason)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '该结果用于健康管理提示，不能替代医生诊断；如有明显不适请及时就医。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(),
              const SizedBox(height: AppSpacing.xs),
              const _RiskDialogActions(),
            ],
          ),
        ),
      ),
    );
  }
}

class _RiskDialogActions extends StatelessWidget {
  const _RiskDialogActions();

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 600;
    final outlineStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    );
    final trendButton = OutlinedButton.icon(
      style: outlineStyle,
      onPressed: () => Navigator.of(context, rootNavigator: true)
          .pop(HealthRiskAction.trend),
      icon: const Icon(Icons.show_chart_rounded),
      label: const Text('查看趋势'),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true)
                .pop(HealthRiskAction.later),
            child: const Text('稍后处理'),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (wide)
          Row(
            children: [
              Expanded(child: trendButton),
            ],
          )
        else ...[
          trendButton,
        ],
        const SizedBox(height: AppSpacing.sm),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: AppColors.emergency,
          ),
          onPressed: () => Navigator.of(context, rootNavigator: true)
              .pop(HealthRiskAction.sos),
          icon: const Icon(Icons.sos_rounded),
          label: const Text('进入 SOS'),
        ),
      ],
    );
  }
}

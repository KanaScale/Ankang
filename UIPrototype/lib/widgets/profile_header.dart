import 'package:flutter/material.dart';

import '../app/design_tokens.dart';
import 'avatar_view.dart';
import 'glass_card.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.name,
    required this.status,
    required this.completion,
    this.completionLabel = '\u5065\u5eb7\u6863\u6848',
    this.avatarInitials,
  });

  final String name;
  final String status;
  final double completion;
  final String completionLabel;
  final String? avatarInitials;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        children: [
          AvatarView(size: 82, initials: avatarInitials ?? name),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  status,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: completion,
                    minHeight: 7,
                    backgroundColor: AppColors.peachSurface,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$completionLabel ${(completion * 100).round()}% 完成',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
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

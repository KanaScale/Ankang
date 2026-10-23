import 'package:flutter/material.dart';

import '../app/design_tokens.dart';
import '../app/app_runtime_settings.dart';
import 'pressable_scale.dart';

enum PrimaryButtonTone { primary, secondary, danger }

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.tone = PrimaryButtonTone.primary,
  });

  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final PrimaryButtonTone tone;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final colors = _ButtonColors.resolve(tone);
    final buttonHeight =
        AppRuntimeSettings.instance.largeTouchTarget ? 64.0 : 56.0;
    final iconSize = AppRuntimeSettings.instance.largeTouchTarget ? 24.0 : 20.0;

    return PressableScale(
      onTap: enabled ? onPressed : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: enabled ? 1 : 0.62,
        child: Container(
          width: double.infinity,
          height: buttonHeight,
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: colors.border == null
                ? null
                : Border.all(color: colors.border!),
            boxShadow:
                tone == PrimaryButtonTone.primary ? AppShadows.card : null,
          ),
          child: Center(
            child: loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(colors.foreground),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: iconSize, color: colors.foreground),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      Flexible(
                        child: Text(
                          text,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: colors.foreground,
                                  ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _ButtonColors {
  const _ButtonColors({
    required this.background,
    required this.foreground,
    this.border,
  });

  final Color background;
  final Color foreground;
  final Color? border;

  static _ButtonColors resolve(PrimaryButtonTone tone) {
    return switch (tone) {
      PrimaryButtonTone.primary => const _ButtonColors(
          background: AppColors.primary,
          foreground: Colors.white,
        ),
      PrimaryButtonTone.secondary => const _ButtonColors(
          background: AppColors.surface,
          foreground: AppColors.textPrimary,
          border: AppColors.border,
        ),
      PrimaryButtonTone.danger => const _ButtonColors(
          background: AppColors.emergency,
          foreground: Colors.white,
        ),
    };
  }
}

import 'package:flutter/material.dart';

import '../app/design_tokens.dart';
import '../app/app_runtime_settings.dart';
import 'pressable_scale.dart';

enum LargePrimaryButtonTone { primary, secondary, danger }

class LargePrimaryButton extends StatelessWidget {
  const LargePrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.tone = LargePrimaryButtonTone.primary,
  });

  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final LargePrimaryButtonTone tone;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final colors = _LargeButtonColors.resolve(tone);
    final buttonHeight =
        AppRuntimeSettings.instance.largeTouchTarget ? 68.0 : 58.0;
    final iconSize = AppRuntimeSettings.instance.largeTouchTarget ? 24.0 : 20.0;

    return PressableScale(
      onTap: enabled ? onPressed : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: enabled ? 1 : 0.55,
        child: Container(
          height: buttonHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: tone == LargePrimaryButtonTone.primary
                ? null
                : colors.background,
            gradient: tone == LargePrimaryButtonTone.primary
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: AppGradients.primaryButton,
                  )
                : null,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: colors.border == null
                ? null
                : Border.all(color: colors.border!),
            boxShadow:
                tone == LargePrimaryButtonTone.primary ? AppShadows.card : null,
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
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: colors.foreground, size: iconSize),
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

class _LargeButtonColors {
  const _LargeButtonColors({
    required this.background,
    required this.foreground,
    this.border,
  });

  final Color background;
  final Color foreground;
  final Color? border;

  static _LargeButtonColors resolve(LargePrimaryButtonTone tone) {
    return switch (tone) {
      LargePrimaryButtonTone.primary => const _LargeButtonColors(
          background: AppColors.primary,
          foreground: Colors.white,
        ),
      LargePrimaryButtonTone.secondary => const _LargeButtonColors(
          background: Color(0xB3FFFFFF),
          foreground: AppColors.textPrimary,
          border: AppColors.border,
        ),
      LargePrimaryButtonTone.danger => const _LargeButtonColors(
          background: AppColors.emergency,
          foreground: Colors.white,
        ),
    };
  }
}

import 'package:flutter/material.dart';

enum CommonButtonType { primary, secondary, danger }

class CommonButton extends StatelessWidget {
  const CommonButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.type = CommonButtonType.primary,
    this.loading = false,
  });

  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final CommonButtonType type;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final backgroundColor = switch (type) {
      CommonButtonType.primary => colors.primary,
      CommonButtonType.secondary => colors.surface,
      CommonButtonType.danger => colors.secondary,
    };
    final foregroundColor = switch (type) {
      CommonButtonType.primary => colors.onPrimary,
      CommonButtonType.secondary => colors.primary,
      CommonButtonType.danger => colors.onSecondary,
    };

    final child = loading
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Flexible(child: Text(text, overflow: TextOverflow.ellipsis)),
            ],
          );

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          side: type == CommonButtonType.secondary
              ? BorderSide(color: colors.primary)
              : null,
        ),
        child: child,
      ),
    );
  }
}

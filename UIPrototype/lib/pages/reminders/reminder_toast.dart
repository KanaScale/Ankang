import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';

OverlayEntry? _activeReminderToast;

/// 展示提醒模块的短时居中反馈；新提示会替换仍在播放的旧提示。
void showReminderToast(
  BuildContext context,
  String message, {
  bool error = false,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  _activeReminderToast?.remove();
  _activeReminderToast = null;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ReminderToastOverlay(
      message: message,
      error: error,
      onDismissed: () {
        if (entry.mounted) entry.remove();
        if (identical(_activeReminderToast, entry)) {
          _activeReminderToast = null;
        }
      },
    ),
  );
  _activeReminderToast = entry;
  overlay.insert(entry);
}

class _ReminderToastOverlay extends StatefulWidget {
  const _ReminderToastOverlay({
    required this.message,
    required this.error,
    required this.onDismissed,
  });

  final String message;
  final bool error;
  final VoidCallback onDismissed;

  @override
  State<_ReminderToastOverlay> createState() => _ReminderToastOverlayState();
}

class _ReminderToastOverlayState extends State<_ReminderToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1080),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDismissed();
      });
    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 1)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 18,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1), weight: 58),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 24,
      ),
    ]).animate(_controller);
    _offset = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween(begin: const Offset(0, 0.28), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: ConstantTween<Offset>(Offset.zero),
        weight: 58,
      ),
      TweenSequenceItem(
        tween: Tween(begin: Offset.zero, end: const Offset(0, -0.22))
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 24,
      ),
    ]).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.error ? AppColors.emergency : AppColors.primary;
    return IgnorePointer(
      child: SafeArea(
        child: Center(
          child: SlideTransition(
            position: _offset,
            child: FadeTransition(
              opacity: _opacity,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 360),
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xF2FFFFFF),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: accent.withValues(alpha: 0.32)),
                    boxShadow: AppShadows.card,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.error
                            ? Icons.error_outline_rounded
                            : Icons.check_circle_outline_rounded,
                        color: accent,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          widget.message,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../models/reminder_model.dart';
import '../../models/reminder_notification_model.dart';
import '../../models/reminder_schedule.dart';
import '../../routes/route_names.dart';
import '../../services/api_client.dart';
import '../../services/offline_session_coordinator.dart';
import '../../services/reminder_notification_service.dart';
import '../../services/reminder_offline_repository.dart';
import '../../services/reminder_service.dart';
import '../../widgets/common/empty_view.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/loading_view.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ios_bottom_navigation.dart';
import '../../widgets/section_title.dart';
import 'reminder_edge_fade.dart';
import 'reminder_form_page.dart';
import 'reminder_management_page.dart';
import 'reminder_toast.dart';

const double _fabBottomPadding = 8;
const double _listBottomClearance = 168;

/// 提醒时间轴页面，所有业务操作经由 [ReminderService] 与后端同步。
class ReminderListPage extends StatefulWidget {
  const ReminderListPage({super.key, this.service});

  /// 便于 widget 测试注入可控实现；生产环境默认使用真实 API Service。
  final ReminderService? service;

  @override
  State<ReminderListPage> createState() => _ReminderListPageState();
}

class _ReminderListPageState extends State<ReminderListPage>
    with WidgetsBindingObserver {
  late final ReminderService _service;
  late final ReminderOfflineRepository _repository;
  final ReminderNotificationService _notificationService =
      const ReminderNotificationService();
  final List<ReminderModel> _reminders = [];
  bool _loading = true;
  bool _mutating = false;
  String? _errorMessage;
  ReminderNotificationReadiness? _notificationReadiness;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service = widget.service ?? ReminderService();
    _repository = ReminderOfflineRepository(remote: _service);
    _loadReminders();
    _loadNotificationReadiness();
  }

  Future<void> _loadNotificationReadiness() async {
    final readiness = await _notificationService.checkReadiness();
    if (mounted) setState(() => _notificationReadiness = readiness);
  }

  Future<void> _requestNotificationPermission() async {
    final readiness = await _notificationService.requestPermission();
    if (mounted) setState(() => _notificationReadiness = readiness);
  }

  Future<void> _openExactAlarmSettings() async {
    await _notificationService.openExactAlarmSettings();
    await _loadNotificationReadiness();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_loading && !_mutating) {
      _loadReminders();
    }
  }

  int? get _ownerUserId => OfflineSessionCoordinator.session.value.ownerUserId;

  Future<void> _loadReminders() async {
    final sessionAtStart = OfflineSessionCoordinator.session.value;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    final cachedOwner = _ownerUserId;
    if (cachedOwner != null) {
      final cached = await _repository.getCachedReminders(cachedOwner);
      if (mounted && cached != null) {
        setState(() {
          _reminders
            ..clear()
            ..addAll(cached);
          _sortReminders();
          _loading = false;
        });
      }
    }
    try {
      final owner = _ownerUserId;
      final response = owner == null
          ? await _service.getReminders()
          : await _repository.getReminders(owner);
      if (!response.success || response.data == null) {
        throw ApiException(response.message);
      }
      if (!mounted ||
          (sessionAtStart.ownerUserId != null &&
              !OfflineSessionCoordinator.session.value.matches(
                sessionAtStart.ownerUserId!,
                sessionAtStart.generation,
              ))) {
        return;
      }
      setState(() {
        _reminders
          ..clear()
          ..addAll(response.data!);
        _sortReminders();
        _loading = false;
      });
      await OfflineSessionCoordinator.reconcileReminders(response.data!);
    } catch (error) {
      if (!mounted ||
          (sessionAtStart.ownerUserId != null &&
              !OfflineSessionCoordinator.session.value.matches(
                sessionAtStart.ownerUserId!,
                sessionAtStart.generation,
              ))) {
        return;
      }
      setState(() {
        _loading = false;
        _errorMessage = _messageFor(error);
      });
    }
  }

  void _sortReminders() {
    _reminders.sort((a, b) {
      final timeOrder = a.remindAt.compareTo(b.remindAt);
      return timeOrder != 0 ? timeOrder : a.id.compareTo(b.id);
    });
  }

  Future<void> _addReminder() async {
    final result = await Navigator.of(context).push<ReminderFormResult>(
      MaterialPageRoute(builder: (_) => const ReminderFormPage()),
    );
    if (!mounted || result is! ReminderFormSaved) return;
    if (result.reminder.enabled &&
        _notificationReadiness?.supported == true &&
        _notificationReadiness?.canNotify != true) {
      await _requestNotificationPermission();
    }
    await _runMutation(() async {
      final owner = _ownerUserId;
      final response = owner == null
          ? await _service.saveReminder(result.reminder)
          : await _repository.create(owner, result.reminder);
      if (!response.success || response.data == null) {
        throw ApiException(response.message);
      }
      _upsertReminder(response.data!);
      await OfflineSessionCoordinator.scheduleReminder(response.data!);
    }, successMessage: _ownerUserId == null ? '提醒已保存' : '已保存到本机');
  }

  Future<void> _editReminder(ReminderModel reminder) async {
    final result = await Navigator.of(context).push<ReminderFormResult>(
      MaterialPageRoute(
        builder: (_) => ReminderFormPage(initialReminder: reminder),
      ),
    );
    if (!mounted || result == null) return;
    switch (result) {
      case ReminderFormSaved(:final reminder):
        await _runMutation(() async {
          final owner = _ownerUserId;
          final response = owner == null
              ? await _service.updateReminder(reminder)
              : await _repository.update(owner, reminder);
          if (!response.success || response.data == null) {
            throw ApiException(response.message);
          }
          _upsertReminder(response.data!);
          await OfflineSessionCoordinator.scheduleReminder(response.data!);
        }, successMessage: _ownerUserId == null ? '提醒已更新' : '已保存到本机');
      case ReminderFormDeleted(:final id):
        await _runMutation(() async {
          final owner = _ownerUserId;
          final response = owner == null
              ? await _service.deleteReminder(id)
              : await _repository.delete(owner, id);
          if (!response.success) throw ApiException(response.message);
          await OfflineSessionCoordinator.cancelReminder(id);
          setState(() => _reminders.removeWhere((item) => item.id == id));
        }, successMessage: _ownerUserId == null ? '提醒已删除' : '已保存到本机');
    }
  }

  Future<void> _openManagement() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ReminderManagementPage(service: _service),
      ),
    );
    if (mounted) await _loadReminders();
  }

  Future<void> _toggleReminderCompletion(ReminderModel reminder) async {
    if (!reminder.enabled || _mutating) return;
    await _runMutation(() async {
      final owner = _ownerUserId;
      final nextCompleted = !reminder.completed;
      final response = owner == null
          ? reminder.completed
              ? await _service.uncompleteReminder(reminder.id)
              : await _service.completeReminder(reminder.id)
          : await _repository.setCompleted(owner, reminder, nextCompleted);
      if (!response.success) throw ApiException(response.message);
      final updated = reminder.copyWith(completed: !reminder.completed);
      _upsertReminder(updated);
      await OfflineSessionCoordinator.scheduleReminder(updated);
    }, successMessage: reminder.completed ? '已取消完成' : '已标记完成');
  }

  Future<void> _runMutation(
    Future<void> Function() operation, {
    required String successMessage,
  }) async {
    if (_mutating) return;
    setState(() => _mutating = true);
    try {
      await operation();
      if (!mounted) return;
      showReminderToast(context, successMessage);
    } catch (error) {
      if (!mounted) return;
      showReminderToast(context, _messageFor(error), error: true);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  void _upsertReminder(ReminderModel reminder) {
    setState(() {
      final index = _reminders.indexWhere((item) => item.id == reminder.id);
      if (index < 0) {
        _reminders.add(reminder);
      } else {
        _reminders[index] = reminder;
      }
      _sortReminders();
    });
  }

  String _messageFor(Object error) =>
      error is ApiException ? error.message : '操作失败，请稍后重试';

  List<ReminderModel> get _todayReminders {
    final today =
        _reminders.where((item) => ReminderSchedule.isDueToday(item)).toList();
    today.sort((left, right) {
      final leftMinutes = left.remindAt.hour * 60 + left.remindAt.minute;
      final rightMinutes = right.remindAt.hour * 60 + right.remindAt.minute;
      final byTime = leftMinutes.compareTo(rightMinutes);
      return byTime != 0 ? byTime : left.id.compareTo(right.id);
    });
    return today;
  }

  int? _nextReminderIndex(List<ReminderModel> reminders) {
    final index = reminders.indexWhere((item) => !item.completed);
    return index == -1 ? null : index;
  }

  @override
  Widget build(BuildContext context) {
    final todayReminders = _todayReminders;
    final nextIndex = _nextReminderIndex(todayReminders);
    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, AppSpacing.lg, 14, 0),
              child: Row(
                children: [
                  const Expanded(child: SectionTitle(title: '今日待办')),
                  TextButton.icon(
                    key: const Key('all-reminders-entry'),
                    onPressed: _mutating ? null : _openManagement,
                    icon: const Icon(Icons.tune_rounded),
                    label: const Text('全部提醒'),
                  ),
                ],
              ),
            ),
            if (!_loading && _errorMessage == null && todayReminders.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  22,
                  AppSpacing.md,
                  22,
                  AppSpacing.lg,
                ),
                child: _ReminderSummary(
                  reminders: todayReminders,
                  nextIndex: nextIndex,
                  notificationReadiness: _notificationReadiness,
                  onRequestPermission: _requestNotificationPermission,
                  onOpenExactAlarmSettings: _openExactAlarmSettings,
                ),
              ),
            Expanded(
              child: _buildContent(todayReminders, nextIndex),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: _fabBottomPadding),
        child: _ReminderActionButton(
          onPressed: _loading || _mutating ? null : _addReminder,
          label: _mutating ? '正在同步…' : '添加提醒',
        ),
      ),
      bottomNavigationBar:
          const IosBottomNavigation(currentRoute: RouteNames.reminder),
    );
  }

  Widget _buildContent(List<ReminderModel> reminders, int? nextIndex) {
    if (_loading) return const LoadingView(message: '正在加载提醒');
    if (_errorMessage != null) {
      return ErrorView(message: _errorMessage!, onRetry: _loadReminders);
    }
    if (reminders.isEmpty) {
      return _ScrollableReminderState(
        child: EmptyView(
          title: _reminders.isEmpty ? '还没有提醒' : '今天暂无提醒',
          message: _reminders.isEmpty
              ? '添加服药、测量或复诊提醒，重要事项不遗漏。'
              : '未来或已停用的提醒可在“全部提醒”中管理。',
          action: _reminders.isEmpty
              ? null
              : OutlinedButton.icon(
                  onPressed: _openManagement,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('查看全部提醒'),
                ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadReminders,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: ReminderEdgeFade(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              22,
              AppSpacing.sm,
              22,
              _listBottomClearance,
            ),
            itemCount: reminders.length,
            itemBuilder: (context, index) => _TimelineItem(
              reminder: reminders[index],
              isFirst: index == 0,
              isLast: index == reminders.length - 1,
              nextUp: nextIndex == index,
              onTap: _mutating ? () {} : () => _editReminder(reminders[index]),
              onToggleCompleted: () =>
                  _toggleReminderCompletion(reminders[index]),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReminderNotificationStatus extends StatelessWidget {
  const _ReminderNotificationStatus({
    required this.readiness,
    required this.onRequestPermission,
    required this.onOpenExactAlarmSettings,
  });

  final ReminderNotificationReadiness readiness;
  final VoidCallback onRequestPermission;
  final VoidCallback onOpenExactAlarmSettings;

  @override
  Widget build(BuildContext context) {
    if (!readiness.supported) {
      return const _ReminderNotificationStatusRow(
        icon: Icons.language_rounded,
        color: AppColors.textTertiary,
        message: '系统到点提醒目前仅支持 Android，网页端保留应用内待办。',
      );
    }
    final permissionMissing = !readiness.canNotify;
    final exactMissing = !readiness.exactAlarmAllowed;
    final message = permissionMissing
        ? '通知权限未开启，到点后无法显示系统提醒。'
        : exactMissing
            ? '精确提醒权限未开启，系统可能延迟几分钟提醒。'
            : '系统提醒已就绪，应用在后台或关闭后仍可到点通知。';
    return _ReminderNotificationStatusRow(
      icon: permissionMissing || exactMissing
          ? Icons.notifications_off_outlined
          : Icons.notifications_active_rounded,
      color: permissionMissing || exactMissing
          ? AppColors.warning
          : AppColors.success,
      message: message,
      actionLabel: permissionMissing
          ? '开启'
          : exactMissing
              ? '设置'
              : null,
      onAction: permissionMissing
          ? onRequestPermission
          : exactMissing
              ? onOpenExactAlarmSettings
              : null,
    );
  }
}

class _ReminderNotificationStatusRow extends StatelessWidget {
  const _ReminderNotificationStatusRow({
    required this.icon,
    required this.color,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color color;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  height: 1.45,
                  color: color == AppColors.warning
                      ? AppColors.warning
                      : AppColors.textTertiary,
                ),
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(width: AppSpacing.xs),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 32),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(actionLabel!),
          ),
        ],
      ],
    );
  }
}

class _ReminderActionButton extends StatelessWidget {
  const _ReminderActionButton({required this.onPressed, required this.label});

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onPressed,
        child: Ink(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: AppGradients.primaryButton),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: Colors.white.withValues(alpha: 0.68)),
            boxShadow: AppShadows.soft,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white,
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

/// 空状态同样保留可滚动的底部避让区，低高度窗口不会被悬浮按钮盖住。
class _ScrollableReminderState extends StatelessWidget {
  const _ScrollableReminderState({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight > _listBottomClearance
            ? constraints.maxHeight - _listBottomClearance
            : 0.0;
        final contentHeight = availableHeight < 240 ? 240.0 : availableHeight;
        return ListView(
          padding: const EdgeInsets.only(bottom: _listBottomClearance),
          children: [SizedBox(height: contentHeight, child: child)],
        );
      },
    );
  }
}

class _ReminderSummary extends StatelessWidget {
  const _ReminderSummary({
    required this.reminders,
    required this.nextIndex,
    required this.notificationReadiness,
    required this.onRequestPermission,
    required this.onOpenExactAlarmSettings,
  });

  final List<ReminderModel> reminders;
  final int? nextIndex;
  final ReminderNotificationReadiness? notificationReadiness;
  final VoidCallback onRequestPermission;
  final VoidCallback onOpenExactAlarmSettings;

  @override
  Widget build(BuildContext context) {
    final completed = reminders.where((item) => item.completed).length;
    final next = nextIndex == null ? null : reminders[nextIndex!];
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.greenSurface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: const Icon(
                  Icons.alarm_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      next == null
                          ? '今日提醒已完成'
                          : '下一次提醒 ${_timeLabel(next.remindAt)}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '今天 ${reminders.length} 项提醒，已完成 $completed 项。',
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (notificationReadiness != null) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
            _ReminderNotificationStatus(
              readiness: notificationReadiness!,
              onRequestPermission: onRequestPermission,
              onOpenExactAlarmSettings: onOpenExactAlarmSettings,
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.reminder,
    required this.isFirst,
    required this.isLast,
    required this.nextUp,
    required this.onTap,
    required this.onToggleCompleted,
  });

  final ReminderModel reminder;
  final bool isFirst;
  final bool isLast;
  final bool nextUp;
  final VoidCallback onTap;
  final VoidCallback onToggleCompleted;

  @override
  Widget build(BuildContext context) {
    const itemHeight = 150.0;
    const timelineWidth = 48.0;
    final completed = reminder.completed;
    final color = completed
        ? AppColors.success
        : nextUp
            ? AppColors.chartOrange
            : AppColors.textTertiary;
    final checkboxSize = nextUp ? 32.0 : 27.0;
    final icon = _iconForType(reminder.type);
    final cardShadows = nextUp
        ? [
            ...AppShadows.card,
            BoxShadow(
              color: AppColors.chartOrange.withValues(alpha: 0.40),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ]
        : completed
            ? AppShadows.subtle
            : AppShadows.card;
    final cardContent = GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      borderColor: nextUp ? AppColors.chartOrange : const Color(0xB3FFFFFF),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: nextUp || completed
                  ? AppColors.greenSurface
                  : AppColors.warmSurface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        decoration:
                            completed ? TextDecoration.lineThrough : null,
                        color: completed
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                ),
                if (reminder.syncState != ReminderSyncState.synced) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    reminder.syncState == ReminderSyncState.failed
                        ? '同步失败'
                        : '待同步',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: reminder.syncState == ReminderSyncState.failed
                              ? Theme.of(context).colorScheme.error
                              : AppColors.chartOrange,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  !reminder.enabled
                      ? '已停用 · ${reminder.remark?.isNotEmpty == true ? reminder.remark! : '暂无备注'}'
                      : reminder.remark?.isNotEmpty == true
                          ? reminder.remark!
                          : '暂无备注',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    final card = AnimatedScale(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      scale: nextUp ? 1.05 : 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          boxShadow: cardShadows,
        ),
        child: cardContent,
      ),
    );

    return SizedBox(
      height: itemHeight,
      child: Row(
        children: [
          SizedBox(
            width: 66,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _timeLabel(reminder.remindAt),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: nextUp || completed
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: nextUp ? FontWeight.w700 : null,
                    ),
              ),
            ),
          ),
          SizedBox(
            width: timelineWidth,
            height: itemHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (!isFirst)
                  const Positioned(
                    top: 0,
                    bottom: itemHeight / 2,
                    child: SizedBox(
                        width: 2, child: ColoredBox(color: AppColors.border)),
                  ),
                if (!isLast)
                  const Positioned(
                    top: itemHeight / 2,
                    bottom: 0,
                    child: SizedBox(
                        width: 2, child: ColoredBox(color: AppColors.border)),
                  ),
                Tooltip(
                  message: !reminder.enabled
                      ? '提醒已停用'
                      : completed
                          ? '取消完成'
                          : '标记为已完成',
                  child: Semantics(
                    button: reminder.enabled,
                    label: !reminder.enabled
                        ? '${reminder.title}已停用'
                        : completed
                            ? '取消${reminder.title}的完成状态'
                            : '标记${reminder.title}为已完成',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: reminder.enabled ? onToggleCompleted : null,
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            width: checkboxSize,
                            height: checkboxSize,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: completed
                                  ? AppColors.success
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(
                                nextUp ? AppSpacing.xs : AppSpacing.xxs,
                              ),
                              border: Border.all(
                                color: completed
                                    ? AppColors.success
                                    : nextUp
                                        ? AppColors.chartOrange
                                        : AppColors.textTertiary,
                                width: nextUp ? 2.5 : 2,
                              ),
                              boxShadow: nextUp && !completed
                                  ? [
                                      BoxShadow(
                                        color: AppColors.chartOrange
                                            .withValues(alpha: 0.32),
                                        blurRadius: 12,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: completed
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 15,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
              child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: card)),
        ],
      ),
    );
  }
}

IconData _iconForType(ReminderType type) => switch (type) {
      ReminderType.medicine => Icons.medication_rounded,
      ReminderType.bloodPressure => Icons.monitor_heart_rounded,
      ReminderType.bloodSugar => Icons.bloodtype_rounded,
      ReminderType.checkup => Icons.assignment_rounded,
      ReminderType.other => Icons.directions_walk_rounded,
    };

String _timeLabel(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

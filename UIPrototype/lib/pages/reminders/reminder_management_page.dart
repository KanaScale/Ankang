import 'package:flutter/material.dart';

import '../../app/app_runtime_settings.dart';
import '../../app/design_tokens.dart';
import '../../models/reminder_model.dart';
import '../../models/reminder_schedule.dart';
import '../../services/api_client.dart';
import '../../services/offline_session_coordinator.dart';
import '../../services/reminder_offline_repository.dart';
import '../../services/reminder_service.dart';
import '../../widgets/common/empty_view.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/loading_view.dart';
import '../../widgets/glass_card.dart';
import 'reminder_edge_fade.dart';
import 'reminder_form_page.dart';
import 'reminder_toast.dart';

const double _fabBottomPadding = 8;
const double _listBottomClearance = 168;

enum _ReminderFilter { all, enabled, disabled }

/// 当前用户全部提醒的集中管理页，不注册公共路由。
class ReminderManagementPage extends StatefulWidget {
  const ReminderManagementPage({super.key, this.service});

  final ReminderService? service;

  @override
  State<ReminderManagementPage> createState() => _ReminderManagementPageState();
}

class _ReminderManagementPageState extends State<ReminderManagementPage>
    with WidgetsBindingObserver {
  late final ReminderService _service;
  late final ReminderOfflineRepository _repository;
  final List<ReminderModel> _reminders = [];
  _ReminderFilter _filter = _ReminderFilter.all;
  bool _loading = true;
  bool _mutating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service = widget.service ?? ReminderService();
    _repository = ReminderOfflineRepository(remote: _service);
    _loadReminders();
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
    _reminders.sort(ReminderSchedule.compareForManagement);
  }

  List<ReminderModel> get _visibleReminders => _reminders.where((item) {
        return switch (_filter) {
          _ReminderFilter.all => true,
          _ReminderFilter.enabled => item.enabled,
          _ReminderFilter.disabled => !item.enabled,
        };
      }).toList();

  Future<void> _addReminder() async {
    final result = await Navigator.of(context).push<ReminderFormResult>(
      MaterialPageRoute(builder: (_) => const ReminderFormPage()),
    );
    if (!mounted || result is! ReminderFormSaved) return;
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

  Future<void> _toggleReminder(ReminderModel reminder, bool enabled) async {
    if (_mutating || enabled == reminder.enabled) return;
    await _runMutation(() async {
      final owner = _ownerUserId;
      final updated = reminder.copyWith(enabled: enabled);
      final response = owner == null
          ? await _service.updateReminder(updated)
          : await _repository.update(owner, updated);
      if (!response.success || response.data == null) {
        throw ApiException(response.message);
      }
      _upsertReminder(response.data!);
      await OfflineSessionCoordinator.scheduleReminder(response.data!);
    }, successMessage: enabled ? '提醒已启用' : '提醒已停用');
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppRuntimeSettings.instance,
      builder: (context, _) {
        final simpleMode = AppRuntimeSettings.instance.simpleMode;
        return Scaffold(
          appBar: AppBar(
            title: Text(simpleMode ? '启用提醒' : '全部提醒'),
          ),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FilterBar(
                  selected: _filter,
                  reminders: _reminders,
                  onSelected: (value) => setState(() => _filter = value),
                ),
                Expanded(child: _buildBody(simpleMode: simpleMode)),
              ],
            ),
          ),
          floatingActionButton: Padding(
            padding: const EdgeInsets.only(bottom: _fabBottomPadding),
            child: _ReminderActionButton(
              onPressed: _loading || _mutating ? null : _addReminder,
              label: '添加提醒',
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody({required bool simpleMode}) {
    if (_loading) return const LoadingView(message: '正在加载全部提醒');
    if (_errorMessage != null) {
      return ErrorView(message: _errorMessage!, onRetry: _loadReminders);
    }

    final reminders = simpleMode
        ? _visibleReminders
            .take(AppRuntimeSettings.instance.simpleListLimit)
            .toList()
        : _visibleReminders;
    if (reminders.isEmpty) {
      return _ScrollableManagementState(
        child: EmptyView(
          title: _reminders.isEmpty ? '还没有提醒' : '没有符合条件的提醒',
          message:
              _reminders.isEmpty ? '添加第一条提醒后，可以在这里集中管理。' : '可以切换上方状态筛选查看其他提醒。',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReminders,
      child: ReminderEdgeFade(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            _listBottomClearance,
          ),
          itemCount: reminders.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            final reminder = reminders[index];
            return _ManagementCard(
              reminder: reminder,
              compact: simpleMode,
              busy: _mutating,
              onTap: () => _editReminder(reminder),
              onEnabledChanged: (value) => _toggleReminder(reminder, value),
            );
          },
        ),
      ),
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

/// 过滤结果为空时仍允许滑动，并为右下角添加按钮保留碰撞空间。
class _ScrollableManagementState extends StatelessWidget {
  const _ScrollableManagementState({required this.child});

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

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.reminders,
    required this.onSelected,
  });

  final _ReminderFilter selected;
  final List<ReminderModel> reminders;
  final ValueChanged<_ReminderFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final enabled = reminders.where((item) => item.enabled).length;
    final disabled = reminders.length - enabled;
    final labels = <_ReminderFilter, String>{
      _ReminderFilter.all: '全部 ${reminders.length}',
      _ReminderFilter.enabled: '已启用 $enabled',
      _ReminderFilter.disabled: '已停用 $disabled',
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: _ReminderFilter.values.map((filter) {
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: ChoiceChip(
              label: Text(labels[filter]!),
              selected: selected == filter,
              onSelected: (_) => onSelected(filter),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ManagementCard extends StatelessWidget {
  const _ManagementCard({
    required this.reminder,
    required this.compact,
    required this.busy,
    required this.onTap,
    required this.onEnabledChanged,
  });

  final ReminderModel reminder;
  final bool compact;
  final bool busy;
  final VoidCallback onTap;
  final ValueChanged<bool> onEnabledChanged;

  @override
  Widget build(BuildContext context) {
    final expired =
        reminder.enabled && ReminderSchedule.isExpiredOnce(reminder);
    final status = _statusLabel(reminder, expired);
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          dense: compact,
          onTap: busy ? null : onTap,
          leading: CircleAvatar(
            backgroundColor: reminder.enabled
                ? AppColors.backgroundWarm
                : AppColors.warmSurface,
            child: Icon(
              _iconForType(reminder.type),
              color: reminder.enabled
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
          ),
          title: Text(
            reminder.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_scheduleLabel(reminder)),
                if (!compact) ...[
                  const SizedBox(height: 2),
                  Text(
                    status,
                    style: TextStyle(
                      color: expired
                          ? Theme.of(context).colorScheme.error
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          trailing: Switch(
            value: reminder.enabled,
            onChanged: busy ? null : onEnabledChanged,
          ),
        ),
      ),
    );
  }
}

String _statusLabel(ReminderModel reminder, bool expired) {
  if (reminder.syncState == ReminderSyncState.failed) return '同步失败';
  if (reminder.syncState == ReminderSyncState.pending) return '待同步';
  if (!reminder.enabled) return '已停用';
  if (expired) return '已过期';
  if (!reminder.completed) return '已启用';
  return switch (reminder.repeatType) {
    ReminderRepeatType.once => '已完成',
    ReminderRepeatType.daily => '今日已完成',
    ReminderRepeatType.weekly => '本周已完成',
  };
}

String _scheduleLabel(ReminderModel reminder) {
  final time =
      '${_twoDigits(reminder.remindAt.hour)}:${_twoDigits(reminder.remindAt.minute)}';
  return switch (reminder.repeatType) {
    ReminderRepeatType.once =>
      '${reminder.remindAt.year}-${_twoDigits(reminder.remindAt.month)}-'
          '${_twoDigits(reminder.remindAt.day)} $time · 单次',
    ReminderRepeatType.daily => '每天 $time',
    ReminderRepeatType.weekly =>
      '每周${_weekdayLabel(reminder.remindAt.weekday)} $time',
  };
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _weekdayLabel(int weekday) =>
    const ['一', '二', '三', '四', '五', '六', '日'][weekday - 1];

IconData _iconForType(ReminderType type) => switch (type) {
      ReminderType.medicine => Icons.medication_rounded,
      ReminderType.bloodPressure => Icons.monitor_heart_rounded,
      ReminderType.bloodSugar => Icons.bloodtype_rounded,
      ReminderType.checkup => Icons.assignment_rounded,
      ReminderType.other => Icons.more_horiz_rounded,
    };

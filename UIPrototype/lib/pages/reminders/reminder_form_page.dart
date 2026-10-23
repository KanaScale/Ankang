import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../models/reminder_model.dart';
import '../../widgets/common/common_button.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/large_primary_button.dart';
import 'reminder_date_picker.dart';
import 'reminder_edge_fade.dart';
import 'reminder_time_picker.dart';

sealed class ReminderFormResult {
  const ReminderFormResult();
}

class ReminderFormSaved extends ReminderFormResult {
  const ReminderFormSaved(this.reminder);

  final ReminderModel reminder;
}

class ReminderFormDeleted extends ReminderFormResult {
  const ReminderFormDeleted(this.id);

  final int id;
}

/// 新增/编辑共用的两步表单，只收集操作结果，不直接发起网络请求。
class ReminderFormPage extends StatefulWidget {
  const ReminderFormPage({super.key, this.initialReminder});

  final ReminderModel? initialReminder;

  @override
  State<ReminderFormPage> createState() => _ReminderFormPageState();
}

class _ReminderFormPageState extends State<ReminderFormPage> {
  // ---- 步骤状态 ----
  int _currentStep = 0;

  // ---- 表单数据 ----
  DateTime _selectedDate = DateTime.now();
  int _selectedHour = 9;
  int _selectedMinute = 0;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  FocusNode? _titleFocusNode;
  String _selectedType = 'medicine';
  String _selectedRepeat = 'once';

  // ---- 提醒类型选项 ----
  static const List<_Option> _typeOptions = [
    _Option('medicine', '服药', Icons.medication_rounded),
    _Option('bloodPressure', '测血压', Icons.monitor_heart_rounded),
    _Option('bloodSugar', '测血糖', Icons.bloodtype_rounded),
    _Option('checkup', '体检', Icons.assignment_rounded),
    _Option('other', '其他', Icons.more_horiz_rounded),
  ];

  // ---- 重复类型选项 ----
  static const List<_RepeatOption> _repeatOptions = [
    _RepeatOption('once', '不重复', Icons.block_rounded),
    _RepeatOption('daily', '每天', Icons.repeat_rounded),
    _RepeatOption('weekly', '每周', Icons.date_range_rounded),
  ];

  bool get _isEditing => widget.initialReminder != null;

  @override
  void initState() {
    super.initState();
    final reminder = widget.initialReminder;
    if (reminder == null) return;

    // 编辑模式完整回填，保存时再保留 ID、启用状态和完成状态。
    _selectedDate = reminder.remindAt;
    _selectedHour = reminder.remindAt.hour;
    _selectedMinute = reminder.remindAt.minute;
    _titleController.text = reminder.title;
    _noteController.text = reminder.remark ?? '';
    _selectedType = reminder.type.name;
    _selectedRepeat = reminder.repeatType.name;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _titleFocusNode?.dispose();
    super.dispose();
  }

  // ========== 步骤切换 ==========

  void _goToStep(int step) => setState(() => _currentStep = step);

  DateTime get _selectedRemindAt => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedHour,
        _selectedMinute,
      );

  Future<bool> _validateReminderTime() async {
    if (_selectedRepeat != ReminderRepeatType.once.name ||
        _selectedRemindAt.isAfter(DateTime.now())) {
      return true;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('请选择未来时间'),
        content: const Text('一次性提醒的时间必须晚于当前时间。'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('重新选择'),
          ),
        ],
      ),
    );
    return false;
  }

  Future<void> _handleNext() async {
    if (await _validateReminderTime() && mounted) {
      _goToStep(1);
    }
  }

  Future<void> _handleSubmit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      await _showMissingTitleDialog();
      return;
    }
    if (!await _validateReminderTime() || !mounted) {
      return;
    }
    final remindAt = _selectedRemindAt;
    final original = widget.initialReminder;
    Navigator.of(context).pop(
      ReminderFormSaved(
        ReminderModel(
          id: original?.id ?? 0,
          title: title,
          type: ReminderType.values.byName(_selectedType),
          remindAt: remindAt,
          repeatType: ReminderRepeatType.values.byName(_selectedRepeat),
          enabled: original?.enabled ?? true,
          completed: original?.completed ?? false,
          remark: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        ),
      ),
    );
  }

  Future<void> _handleDelete() async {
    final reminder = widget.initialReminder;
    if (reminder == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除提醒'),
        content: Text('确定删除“${reminder.title}”吗？删除后无法恢复。'),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                    child: const Text('删除'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop(ReminderFormDeleted(reminder.id));
    }
  }

  Future<void> _showMissingTitleDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  child: Container(
                    width: 58,
                    height: 58,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.backgroundWarm,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      color: AppColors.primary,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '请完善提醒',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '“提醒标题”是必填项，请填写后再保存。',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xl),
                CommonButton(
                  text: '去填写',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    _effectiveTitleFocusNode.requestFocus();
  }

  /// 懒初始化可兼容 Web 热重载前已经存在的 State 实例。
  FocusNode get _effectiveTitleFocusNode =>
      _titleFocusNode ??= FocusNode(debugLabel: 'reminder-title');

  /// GlassCard 包裹的文本输入框
  Widget _buildGlassInput({
    required TextEditingController controller,
    String? hintText,
    IconData? prefixIcon,
    FocusNode? focusNode,
    int maxLines = 1,
    int? maxLength,
  }) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLines: maxLines,
        maxLength: maxLength,
        decoration: InputDecoration(
          counterText: '',
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: TextStyle(color: AppColors.textTertiary),
          prefixIcon: prefixIcon == null
              ? null
              : Icon(prefixIcon, color: AppColors.textSecondary, size: 20),
        ),
      ),
    );
  }

  // ========== 日期选择 ==========

  Future<void> _pickDate() async {
    final date = await showReminderDatePicker(
      context,
      initialDate: _selectedDate,
    );
    if (date != null && mounted) setState(() => _selectedDate = date);
  }

  String get _repeatLabel => _repeatOptions
      .firstWhere((option) => option.value == _selectedRepeat)
      .label;

  Future<void> _pickRepeat() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('重复方式', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.md),
                ..._repeatOptions.map((option) {
                  final active = option.value == _selectedRepeat;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Material(
                      color: active
                          ? AppColors.backgroundWarm
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: ListTile(
                        minVerticalPadding: AppSpacing.md,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        leading: Icon(
                          option.icon,
                          color: active
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        title: Text(option.label),
                        trailing: active
                            ? const Icon(Icons.check_rounded,
                                color: AppColors.primary)
                            : null,
                        onTap: () =>
                            Navigator.of(dialogContext).pop(option.value),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _selectedRepeat = selected);
    }
  }

  Future<void> _pickTime() async {
    final time = await showReminderTimePicker(
      context,
      initialTime: TimeOfDay(hour: _selectedHour, minute: _selectedMinute),
    );
    if (time == null || !mounted) return;
    setState(() {
      _selectedHour = time.hour;
      _selectedMinute = time.minute;
    });
  }

  // ========== 构建 ==========

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Text(_isEditing ? '编辑提醒' : '添加提醒'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (_currentStep == 0) {
              Navigator.of(context).pop();
            } else {
              _goToStep(0);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              key: const Key('reminder-form-step-header'),
              padding: const EdgeInsets.fromLTRB(
                22,
                AppSpacing.sm,
                22,
                AppSpacing.sm,
              ),
              child: _StepIndicator(currentStep: _currentStep),
            ),
            Expanded(
              key: const Key('reminder-form-scroll-region'),
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  scrollbars: false,
                ),
                child: ReminderEdgeFade(
                  child: SingleChildScrollView(
                    key: ValueKey(_currentStep),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(
                      22,
                      AppSpacing.xl,
                      22,
                      AppSpacing.xxl,
                    ),
                    child: _currentStep == 0
                        ? _buildTimeStep()
                        : _buildDetailStep(),
                  ),
                ),
              ),
            ),
            Padding(
              key: const Key('reminder-form-bottom-action'),
              padding: const EdgeInsets.fromLTRB(
                22,
                AppSpacing.sm,
                22,
                AppSpacing.lg,
              ),
              child: _buildBottomAction(),
            ),
          ],
        ),
      ),
    );
  }

  /// 编辑模式将危险操作与保存操作并排展示，减少底部区域纵向占用。
  Widget _buildBottomAction() {
    if (_currentStep == 0) {
      return LargePrimaryButton(
        text: '下一步',
        icon: Icons.arrow_forward_rounded,
        onPressed: _handleNext,
      );
    }
    if (!_isEditing) {
      return LargePrimaryButton(
        text: '保存提醒',
        icon: Icons.check_rounded,
        onPressed: _handleSubmit,
      );
    }
    return Row(
      children: [
        Expanded(
          child: LargePrimaryButton(
            text: '删除提醒',
            icon: Icons.delete_outline_rounded,
            tone: LargePrimaryButtonTone.danger,
            onPressed: _handleDelete,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: LargePrimaryButton(
            text: '保存修改',
            icon: Icons.check_rounded,
            onPressed: _handleSubmit,
          ),
        ),
      ],
    );
  }

  // ==================== 步骤一：设定提醒时间 ====================

  Widget _buildTimeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('设定提醒时间', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text('保存后可在应用内查看；在权限允许时可接收系统提醒。',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.xxl),

        // ---- 日期选择卡片 ----
        ReminderDatePickerCard(
          date: _selectedDate,
          onTap: _pickDate,
        ),
        const SizedBox(height: AppSpacing.md),

        // ---- 时间选择卡片（点击弹出滚动选择窗口） ----
        ReminderTimePickerCard(
          label: '时间',
          time: TimeOfDay(hour: _selectedHour, minute: _selectedMinute),
          onTap: _pickTime,
        ),
        const SizedBox(height: AppSpacing.md),

        // ---- 重复方式入口 ----
        _RepeatPickerCard(
          value: _repeatLabel,
          onTap: _pickRepeat,
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  // ==================== 步骤二：设定提醒事项 ====================

  Widget _buildDetailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('设定提醒事项', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text('填写提醒的具体内容。',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.xxl),

        // ---- 提醒标题输入 ----
        _LabeledSection(
          label: '提醒标题',
          child: _buildGlassInput(
            controller: _titleController,
            maxLength: 128,
            focusNode: _effectiveTitleFocusNode,
            hintText: '例如：早晨降压药',
            prefixIcon: Icons.edit_rounded,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ---- 提醒类型选择 ----
        _LabeledSection(
          label: '提醒类型',
          child: _OptionGrid(
            options: _typeOptions,
            selected: _selectedType,
            onChanged: (v) => setState(() => _selectedType = v),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ---- 备注输入 ----
        _LabeledSection(
          label: '备注（选填）',
          child: _buildGlassInput(
            controller: _noteController,
            maxLength: 255,
            hintText: '例如：饭后服用，每次 1 片',
            prefixIcon: Icons.notes_rounded,
            maxLines: 2,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

// ==================== 步骤指示器组件 ====================

/// 两步步骤指示器：带标签的圆点 + 连接线
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StepDot(step: 0, currentStep: currentStep, label: '设定时间'),
        Container(
          width: 56,
          height: 2,
          margin: const EdgeInsets.only(bottom: AppSpacing.xl),
          color: currentStep >= 1 ? AppColors.primary : AppColors.border,
        ),
        _StepDot(step: 1, currentStep: currentStep, label: '设定事项'),
      ],
    );
  }
}

/// 步骤圆点 + 下方标签
class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.step,
    required this.currentStep,
    required this.label,
  });

  final int step;
  final int currentStep;
  final String label;

  @override
  Widget build(BuildContext context) {
    final bool active = currentStep >= step;
    final bool isCurrent = currentStep == step;
    final Color bgColor = active ? AppColors.primary : AppColors.border;
    final Color textColor = active ? AppColors.primary : AppColors.textTertiary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isCurrent ? 36 : 28,
          height: isCurrent ? 36 : 28,
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          child: Center(
            child: isCurrent
                ? Text('${step + 1}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Colors.white))
                : active
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 18)
                    : Text('${step + 1}',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.textTertiary)),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: textColor,
                fontWeight: isCurrent ? FontWeight.w600 : null,
              ),
        ),
      ],
    );
  }
}

// ==================== 通用子组件 ====================

/// 带标签的区块容器
class _LabeledSection extends StatelessWidget {
  const _LabeledSection({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
              left: AppSpacing.xxs, bottom: AppSpacing.sm),
          child: Text(label,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: AppColors.textPrimary)),
        ),
        child,
      ],
    );
  }
}

/// 重复方式入口，与日期和时间入口保持同一视觉结构。
class _RepeatPickerCard extends StatelessWidget {
  const _RepeatPickerCard({
    required this.value,
    required this.onTap,
  });

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: const Icon(Icons.repeat_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('重复方式',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: AppSpacing.xxs),
                Text(value, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textTertiary),
        ],
      ),
    );
  }
}

/// 提醒类型选项网格。
class _OptionGrid extends StatelessWidget {
  const _OptionGrid({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<_Option> options;
  final String selected;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: options.map((opt) {
        final bool active = selected == opt.value;
        return GestureDetector(
          onTap: () => onChanged(opt.value),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: active ? AppColors.primary : AppColors.surfaceGlass,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: active ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(opt.icon,
                    size: 18,
                    color: active ? Colors.white : AppColors.textSecondary),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  opt.label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: active ? Colors.white : AppColors.textPrimary,
                        fontWeight: active ? FontWeight.w600 : null,
                      ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// 选项数据类
class _Option {
  const _Option(this.value, this.label, this.icon);
  final String value;
  final String label;
  final IconData icon;
}

class _RepeatOption {
  const _RepeatOption(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;
}

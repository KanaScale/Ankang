import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_runtime_settings.dart';
import '../../app/design_tokens.dart';
import '../../models/device_sync_model.dart';
import '../../models/emergency_contact_model.dart';
import '../../models/health_goal_model.dart';
import '../../models/health_event_model.dart';
import '../../models/health_profile_model.dart';
import '../../models/health_record_model.dart';
import '../../models/user_model.dart';
import '../../models/user_setting_model.dart';
import '../../pages/emergency/emergency_page.dart';
import '../../pages/family/family_home_page.dart';
import '../../pages/records/trend_page.dart';
import '../../routes/route_names.dart';
import '../../services/auth_service.dart';
import '../../services/device_sync_service.dart';
import '../../services/emergency_service.dart';
import '../../services/health_event_service.dart';
import '../../services/profile_service.dart';
import '../../utils/validator_util.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/health_risk_dialog.dart';
import '../../widgets/ios_bottom_navigation.dart';
import '../../widgets/page_enter_animation.dart';
import '../../widgets/pressable_scale.dart';
import '../../widgets/profile_header.dart';
import 'personal_info_controller.dart';
import 'settings_controller.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: const _ProfileDashboard(),
      bottomNavigationBar:
          const IosBottomNavigation(currentRoute: RouteNames.profile),
    );
  }
}

class _ProfileDashboard extends StatefulWidget {
  const _ProfileDashboard();

  @override
  State<_ProfileDashboard> createState() => _ProfileDashboardState();
}

class _ProfileDashboardState extends State<_ProfileDashboard> {
  final _profileService = ProfileService();
  final _emergencyService = EmergencyService();
  final _deviceSyncService = DeviceSyncService();

  UserModel? _user = AuthService.currentUser;
  HealthProfileModel? _healthProfile;
  HealthGoalModel? _healthGoal;
  HealthGoalProgressModel? _healthGoalProgress;
  DeviceSyncModel? _device;
  int _emergencyContactCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadDashboard());
  }

  Future<void> _loadDashboard({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() => _loading = true);
    }
    try {
      final userResponse = await _profileService.getCurrentUser();
      final healthResponse = await _profileService.getHealthProfile();
      final goalResponse = await _profileService.getHealthGoals();
      final goalProgressResponse =
          await _profileService.getHealthGoalProgress();
      final contactsResponse = await _emergencyService.getContacts();
      DeviceSyncModel? loadedDevice;
      var hasDeviceResponse = false;
      try {
        final deviceResponse = await _deviceSyncService.getCurrentDevice();
        hasDeviceResponse = deviceResponse.success;
        loadedDevice = deviceResponse.data;
      } catch (_) {
        // Device preview is non-blocking; keep the previous value on failure.
      }
      if (!mounted) {
        return;
      }
      setState(() {
        if (userResponse.success) {
          _user = userResponse.data;
        }
        if (healthResponse.success) {
          _healthProfile = healthResponse.data;
        }
        if (goalResponse.success) {
          _healthGoal = goalResponse.data;
        }
        if (goalProgressResponse.success) {
          _healthGoalProgress = goalProgressResponse.data;
        }
        if (contactsResponse.success) {
          _emergencyContactCount = contactsResponse.data?.length ?? 0;
        }
        if (hasDeviceResponse) {
          _device = loadedDevice;
        }
      });
    } catch (_) {
      // Dashboard keeps the last cached values if a refresh fails.
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppGradients.page,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 112),
          children: [
            PageEnterAnimation(
              child: _ProfileTitle(onLogout: () => _logout(context)),
            ),
            const SizedBox(height: AppSpacing.lg),
            PageEnterAnimation(
              delay: const Duration(milliseconds: 80),
              child: ProfileHeader(
                name: _displayName,
                status: _profileStatus,
                completion: _userInfoCompletion,
                completionLabel: '资料完整度',
                avatarInitials: _displayName,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            PageEnterAnimation(
              delay: const Duration(milliseconds: 140),
              child: _ProfileModules(
                userCompletion: _userInfoCompletion,
                healthProfile: _healthProfile,
                healthGoal: _healthGoal,
                healthGoalProgress: _healthGoalProgress,
                device: _device,
                emergencyContactCount: _emergencyContactCount,
                onSelected: (module) => _openModule(context, module),
              ),
            ),
            if (_loading) ...[
              const SizedBox(height: AppSpacing.sm),
              const Center(child: CircularProgressIndicator()),
            ],
            const SizedBox(height: AppSpacing.lg),
            PageEnterAnimation(
              delay: const Duration(milliseconds: 220),
              child: _DeviceSyncCard(device: _device),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openModule(BuildContext context, _ProfileModule module) async {
    switch (module) {
      case _ProfileModule.emergencyContacts:
        await Navigator.of(context).pushNamed(RouteNames.emergencyContacts);
        break;
      case _ProfileModule.medicalSummary:
        await Navigator.of(context).pushNamed(RouteNames.medicalSummary);
        break;
      default:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => module.page),
        );
    }
    if (mounted) {
      unawaited(_loadDashboard(showLoading: false));
    }
  }

  Future<void> _logout(BuildContext context) async {
    await AuthService().logout().catchError((_) {});
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      RouteNames.login,
      (route) => false,
    );
  }

  String get _displayName {
    return _firstText(_user?.nickname, _user?.username) ?? '未登录用户';
  }

  String get _profileStatus {
    return '个人资料与健康档案';
  }

  double get _userInfoCompletion {
    const total = 5;
    var filled = 0;
    if (_hasText(_user?.nickname)) filled++;
    if (_hasText(_user?.phone)) filled++;
    if (_hasText(_user?.email)) filled++;
    if (_user?.age != null) filled++;
    if (_hasText(_user?.gender)) filled++;
    return filled / total;
  }

  String? _firstText(String? first, String? second) {
    if (_hasText(first)) {
      return first!.trim();
    }
    if (_hasText(second)) {
      return second!.trim();
    }
    return null;
  }

  bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}

class _ProfileTitle extends StatelessWidget {
  const _ProfileTitle({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('我的', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '管理健康档案、目标、联系人和设备。',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: '退出登录',
          onPressed: onLogout,
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
    );
  }
}

class _ProfileModules extends StatelessWidget {
  const _ProfileModules({
    required this.userCompletion,
    required this.healthProfile,
    required this.healthGoal,
    required this.healthGoalProgress,
    required this.device,
    required this.emergencyContactCount,
    required this.onSelected,
  });

  final double userCompletion;
  final HealthProfileModel? healthProfile;
  final HealthGoalModel? healthGoal;
  final HealthGoalProgressModel? healthGoalProgress;
  final DeviceSyncModel? device;
  final int emergencyContactCount;
  final ValueChanged<_ProfileModule> onSelected;

  String get _userCompletionText => '${(userCompletion * 100).round()}%';

  String get _healthValue {
    final bmi = healthProfile?.bmi;
    if (bmi == null || bmi <= 0) {
      return '--';
    }
    return 'BMI ${bmi.toStringAsFixed(1)}';
  }

  String get _healthStatus {
    final profile = healthProfile;
    final hasProfile = profile != null &&
        (profile.height != null ||
            profile.weight != null ||
            profile.chronicDiseases.isNotEmpty ||
            _hasText(profile.allergies) ||
            _hasText(profile.medicalHistory));
    return hasProfile ? '档案已完善' : '待完善';
  }

  String get _goalValue {
    final progress = healthGoalProgress?.steps.progress;
    return progress == null ? '--' : '${(progress * 100).round()}%';
  }

  String get _goalStatus {
    final status = healthGoalProgress?.steps.status;
    if (_hasText(status)) {
      return status!.trim();
    }
    final target = healthGoal?.stepsTarget;
    return target == null || target.trim().isEmpty ? '待设置' : '目标 $target';
  }

  String get _contactSubtitle {
    return emergencyContactCount == 0 ? '暂未设置' : '$emergencyContactCount 位已设置';
  }

  String get _contactValue => '$emergencyContactCount 人';

  String get _contactStatus {
    return emergencyContactCount == 0 ? '待添加' : '可立即联系';
  }

  String get _deviceSubtitle {
    final name = device?.deviceName.trim();
    if (name == null || name.isEmpty) {
      return '设备状态加载中';
    }
    return '$name ${_connectionLabel(device!.connectionStatus)}';
  }

  String get _deviceValue {
    return _formatRelativeSyncTime(device?.lastSyncAt);
  }

  String get _deviceStatus {
    final current = device;
    if (current == null) {
      return '待刷新';
    }
    if (current.connectionStatus == 'offline') {
      return '设备离线';
    }
    return current.lastSyncAt == null ? '待同步' : '同步正常';
  }

  bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      borderRadius: AppRadius.xl,
      child: Column(
        children: [
          _ProfileModuleRow(
            title: '用户信息',
            subtitle: '账号、用户名、手机号',
            value: _userCompletionText,
            status: '资料完整度',
            icon: Icons.badge_rounded,
            color: AppColors.primary,
            onTap: () => onSelected(_ProfileModule.personalInfo),
          ),
          const _ProfileModuleDivider(),
          _ProfileModuleRow(
            title: '健康档案',
            subtitle: '身高、体重、慢病档案',
            value: _healthValue,
            status: _healthStatus,
            icon: Icons.monitor_heart_rounded,
            color: AppColors.chartBlue,
            onTap: () => onSelected(_ProfileModule.healthData),
          ),
          const _ProfileModuleDivider(),
          _ProfileModuleRow(
            title: '就医摘要',
            subtitle: '结构化整理近期客观数据',
            value: '14 天',
            status: '可直接展示',
            icon: Icons.medical_information_rounded,
            color: AppColors.chartBlue,
            onTap: () => onSelected(_ProfileModule.medicalSummary),
          ),
          const _ProfileModuleDivider(),
          _ProfileModuleRow(
            title: '健康目标',
            subtitle: '步数、睡眠、血压',
            value: _goalValue,
            status: _goalStatus,
            icon: Icons.track_changes_rounded,
            color: AppColors.warning,
            onTap: () => onSelected(_ProfileModule.healthGoals),
          ),
          const _ProfileModuleDivider(),
          _ProfileModuleRow(
            title: '紧急联系人',
            subtitle: _contactSubtitle,
            value: _contactValue,
            status: _contactStatus,
            icon: Icons.contact_emergency_rounded,
            color: AppColors.emergency,
            onTap: () => onSelected(_ProfileModule.emergencyContacts),
          ),
          const _ProfileModuleDivider(),
          _ProfileModuleRow(
            title: '家庭照护',
            subtitle: '家属授权与照护查看',
            value: '双角色',
            status: '已启用',
            icon: Icons.family_restroom_rounded,
            color: AppColors.success,
            onTap: () => onSelected(_ProfileModule.familyCare),
          ),
          const _ProfileModuleDivider(),
          _ProfileModuleRow(
            title: '设备同步',
            subtitle: _deviceSubtitle,
            value: _deviceValue,
            status: _deviceStatus,
            icon: Icons.watch_rounded,
            color: AppColors.chartBlue,
            onTap: () => onSelected(_ProfileModule.deviceSync),
          ),
          const _ProfileModuleDivider(),
          _ProfileModuleRow(
            title: '设置',
            subtitle: '字号、通知、大按钮',
            value: '3 项',
            status: '偏好设置',
            icon: Icons.settings_rounded,
            color: AppColors.chartPurple,
            onTap: () => onSelected(_ProfileModule.settings),
          ),
        ],
      ),
    );
  }
}

enum _ProfileModule {
  personalInfo,
  healthData,
  medicalSummary,
  healthGoals,
  emergencyContacts,
  familyCare,
  deviceSync,
  settings;

  Widget get page {
    return switch (this) {
      _ProfileModule.personalInfo => const _PersonalInfoPage(),
      _ProfileModule.healthData => const _PersistentHealthDataPage(),
      _ProfileModule.medicalSummary => const SizedBox.shrink(),
      _ProfileModule.healthGoals => const _HealthGoalsPage(),
      _ProfileModule.emergencyContacts => const _EmergencyContactsPage(),
      _ProfileModule.familyCare => const FamilyCareSettingsPage(),
      _ProfileModule.deviceSync => const _DeviceSyncInteractivePage(),
      _ProfileModule.settings => const _SettingsPage(),
    };
  }
}

class _ProfileModuleRow extends StatelessWidget {
  const _ProfileModuleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.status,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String value;
  final String status;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileModuleDivider extends StatelessWidget {
  const _ProfileModuleDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 66, right: AppSpacing.md),
      child: Container(
        height: 1,
        color: AppColors.border.withValues(alpha: 0.55),
      ),
    );
  }
}

class _DeviceSyncCard extends StatelessWidget {
  const _DeviceSyncCard({required this.device});

  final DeviceSyncModel? device;

  @override
  Widget build(BuildContext context) {
    final current = device;
    final isOffline = current?.connectionStatus == 'offline';
    final color = isOffline ? AppColors.warning : AppColors.primary;
    final title = current == null
        ? '设备同步待加载'
        : isOffline
            ? '设备暂时离线'
            : '设备同步正常';
    final detail = current == null
        ? '正在获取可穿戴设备的最近同步状态'
        : current.lastSyncAt == null
            ? '暂未获取到最近同步时间'
            : '最近同步：${_formatRelativeSyncTime(current.lastSyncAt)}';

    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.sync_rounded, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  detail,
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

class _PersonalInfoPage extends StatefulWidget {
  const _PersonalInfoPage();

  @override
  State<_PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<_PersonalInfoPage> {
  final _formKey = GlobalKey<FormState>();
  final _accountController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _ageController = TextEditingController();
  final _genderController = TextEditingController();
  final _controller = PersonalInfoController();

  @override
  void initState() {
    super.initState();
    for (final controller in _editableControllers) {
      controller.addListener(_handleDraftChanged);
    }
    unawaited(_loadProfile());
  }

  @override
  void dispose() {
    for (final controller in _editableControllers) {
      controller.removeListener(_handleDraftChanged);
    }
    _accountController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _genderController.dispose();
    _controller.dispose();
    super.dispose();
  }

  List<TextEditingController> get _editableControllers => [
        _usernameController,
        _phoneController,
        _emailController,
        _ageController,
        _genderController,
      ];

  void _handleDraftChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadProfile() async {
    await _controller.load();
    if (!mounted) {
      return;
    }
    final user = _controller.user;
    if (user == null) {
      _showMessage(_controller.errorMessage ?? '用户信息加载失败');
      return;
    }
    _applyDraft(PersonalInfoDraft.fromUser(user));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final saved = await _controller.save(_readDraft());
    if (!mounted) {
      return;
    }
    if (!saved) {
      _showMessage(_controller.errorMessage ?? '用户信息保存失败');
      return;
    }
    final user = _controller.user;
    if (user != null) {
      _applyDraft(PersonalInfoDraft.fromUser(user));
    }
    _showMessage('用户信息已保存');
  }

  PersonalInfoDraft _readDraft() {
    return PersonalInfoDraft(
      username: _accountController.text,
      nickname: _usernameController.text,
      phone: _phoneController.text,
      email: _emailController.text,
      age: int.tryParse(_ageController.text.trim()),
      gender: _genderController.text,
      avatarUrl: _controller.user?.avatarUrl,
    );
  }

  void _applyDraft(PersonalInfoDraft draft) {
    _accountController.text = draft.username;
    _usernameController.text = draft.nickname;
    _phoneController.text = draft.phone;
    _emailController.text = draft.email;
    _ageController.text = draft.age?.toString() ?? '';
    _genderController.text = draft.gender;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openChangePassword() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const _ChangePasswordPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final completion = _readDraft().completion;
        return _ProfileDetailScaffold(
          title: '用户信息',
          subtitle: '账号不可修改，其他资料可清空后保存。',
          children: [
            _PersonalInfoPrototypeCard(completion: completion),
            const SizedBox(height: AppSpacing.md),
            if (_controller.loading)
              const Center(child: CircularProgressIndicator())
            else
              GlassCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('账户资料',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _accountController,
                        readOnly: true,
                        enableInteractiveSelection: false,
                        decoration: const InputDecoration(
                          labelText: '账号',
                          helperText: '账号用于登录，不能在个人信息页修改',
                          prefixIcon: Icon(Icons.badge_rounded),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _EditableField(
                        label: '用户名',
                        controller: _usernameController,
                        prefixIcon: Icons.person_rounded,
                        allowClear: true,
                        maxLength: ValidatorUtil.usernameMaxLength,
                        validator: ValidatorUtil.optionalUsername,
                      ),
                      _EditableField(
                        label: '手机号',
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_rounded,
                        allowClear: true,
                        validator: _optionalPhoneValidator,
                      ),
                      _EditableField(
                        label: '邮箱',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.mail_rounded,
                        allowClear: true,
                        validator: _optionalEmailValidator,
                      ),
                      _EditableField(
                        label: '年龄',
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.cake_rounded,
                        allowClear: true,
                        validator: _optionalAgeValidator,
                      ),
                      _GenderDropdown(controller: _genderController),
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: _openChangePassword,
                        icon: const Icon(Icons.lock_reset_rounded),
                        label: const Text('修改密码'),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed:
                  _controller.loading || _controller.saving ? null : _save,
              icon: _controller.saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_controller.saving ? '保存中' : '保存修改'),
            ),
          ],
        );
      },
    );
  }

  String? _optionalPhoneValidator(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    return RegExp(r'^1[3-9]\d{9}$').hasMatch(trimmed) ? null : '请输入正确的手机号';
  }

  String? _optionalEmailValidator(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed)
        ? null
        : '请输入正确的邮箱';
  }

  String? _optionalAgeValidator(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    final age = int.tryParse(trimmed);
    if (age == null || age < 0 || age > 130) {
      return '请输入 0-130 之间的年龄';
    }
    return null;
  }
}

class _PersonalInfoPrototypeCard extends StatelessWidget {
  const _PersonalInfoPrototypeCard({required this.completion});

  final double completion;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_user_rounded,
                color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('资料完整度', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xxs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: completion,
                    minHeight: 7,
                    backgroundColor: AppColors.peachSurface,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${(completion * 100).round()}% 完成',
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

class _ChangePasswordPage extends StatefulWidget {
  const _ChangePasswordPage();

  @override
  State<_ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<_ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _profileService = ProfileService();
  bool _saving = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final response = await _profileService.changePassword(
        oldPassword: _oldPasswordController.text,
        newPassword: _newPasswordController.text,
        confirmPassword: _confirmPasswordController.text,
      );
      if (!mounted) {
        return;
      }
      if (!response.success) {
        _showMessage(response.message.isEmpty ? '密码修改失败' : response.message);
        return;
      }
      _showMessage('密码已修改');
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return _ProfileDetailScaffold(
      title: '修改密码',
      subtitle: '输入原密码后设置新的登录密码',
      children: [
        GlassCard(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _EditableField(
                  label: '原密码',
                  controller: _oldPasswordController,
                  obscureText: true,
                  prefixIcon: Icons.lock_outline_rounded,
                  validator: _passwordValidator,
                ),
                _EditableField(
                  label: '新密码',
                  controller: _newPasswordController,
                  obscureText: true,
                  prefixIcon: Icons.lock_reset_rounded,
                  validator: _passwordValidator,
                ),
                _EditableField(
                  label: '确认新密码',
                  controller: _confirmPasswordController,
                  obscureText: true,
                  prefixIcon: Icons.lock_rounded,
                  validator: (value) {
                    if ((value ?? '').length < 6) {
                      return '密码至少 6 位';
                    }
                    return value == _newPasswordController.text
                        ? null
                        : '两次输入的新密码不一致';
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.lock_reset_rounded),
          label: Text(_saving ? '修改中' : '确认修改'),
        ),
      ],
    );
  }

  String? _passwordValidator(String? value) {
    return value == null || value.length < 6 ? '密码至少 6 位' : null;
  }
}

class _PersistentHealthDataPage extends StatefulWidget {
  const _PersistentHealthDataPage();

  @override
  State<_PersistentHealthDataPage> createState() =>
      _PersistentHealthDataPageState();
}

class _PersistentHealthDataPageState extends State<_PersistentHealthDataPage> {
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _diseasesController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _medicalHistoryController = TextEditingController();
  final _profileService = ProfileService();

  double? _bmi;
  String? _device;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadHealthProfile());
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _diseasesController.dispose();
    _allergiesController.dispose();
    _medicalHistoryController.dispose();
    super.dispose();
  }

  Future<void> _loadHealthProfile() async {
    setState(() => _loading = true);
    try {
      final response = await _profileService.getHealthProfile();
      final profile = response.data;
      if (!mounted) {
        return;
      }
      if (!response.success || profile == null) {
        _showMessage(response.message.isEmpty ? '健康档案加载失败' : response.message);
        return;
      }
      _applyProfile(profile);
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final response = await _profileService.updateHealthProfile(
        HealthProfileModel(
          height: double.tryParse(_heightController.text.trim()),
          weight: double.tryParse(_weightController.text.trim()),
          chronicDiseases: _splitDiseases(_diseasesController.text),
          allergies: _blankToNull(_allergiesController.text),
          medicalHistory: _blankToNull(_medicalHistoryController.text),
          device: _device,
        ),
      );
      final profile = response.data;
      if (!mounted) {
        return;
      }
      if (!response.success || profile == null) {
        _showMessage(response.message.isEmpty ? '健康档案保存失败' : response.message);
        return;
      }
      _applyProfile(profile);
      _showMessage('健康档案已保存');
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _applyProfile(HealthProfileModel profile) {
    _heightController.text = _formatNumber(profile.height);
    _weightController.text = _formatNumber(profile.weight);
    _diseasesController.text = profile.chronicDiseases.join('、');
    _allergiesController.text = profile.allergies ?? '';
    _medicalHistoryController.text = profile.medicalHistory ?? '';
    _bmi = profile.bmi;
    _device = profile.device;
  }

  List<String> _splitDiseases(String value) {
    return value
        .split(RegExp(r'[,，、]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _formatNumber(double? value) {
    if (value == null) {
      return '';
    }
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toString();
  }

  String? _blankToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return _ProfileDetailScaffold(
      title: '健康档案',
      subtitle: '维护身高、体重、慢病、过敏史和既往病史',
      children: [
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else
          _DetailSection(
            title: '基础健康信息',
            rows: [
              _EditableField(
                label: '身高（cm）',
                controller: _heightController,
                keyboardType: TextInputType.number,
              ),
              _EditableField(
                label: '体重（kg）',
                controller: _weightController,
                keyboardType: TextInputType.number,
              ),
              _DetailRow(
                label: 'BMI',
                value: _bmi == null ? '保存后计算' : _bmi!.toStringAsFixed(1),
              ),
              _EditableField(
                label: '慢病类型（用逗号分隔）',
                controller: _diseasesController,
              ),
              _EditableField(label: '过敏史', controller: _allergiesController),
              _EditableField(
                label: '既往病史',
                controller: _medicalHistoryController,
              ),
            ],
          ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: _loading || _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded),
          label: Text(_saving ? '保存中' : '保存健康档案'),
        ),
      ],
    );
  }
}

class _HealthGoalsPage extends StatefulWidget {
  const _HealthGoalsPage();

  @override
  State<_HealthGoalsPage> createState() => _HealthGoalsPageState();
}

class _HealthGoalsPageState extends State<_HealthGoalsPage> {
  final _stepsController = TextEditingController();
  final _sleepController = TextEditingController();
  final _bloodPressureController = TextEditingController();
  final _stepsNoteController = TextEditingController();
  final _sleepNoteController = TextEditingController();
  final _bloodPressureNoteController = TextEditingController();
  final _profileService = ProfileService();
  HealthGoalProgressModel? _progress;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadGoals());
  }

  @override
  void dispose() {
    _stepsController.dispose();
    _sleepController.dispose();
    _bloodPressureController.dispose();
    _stepsNoteController.dispose();
    _sleepNoteController.dispose();
    _bloodPressureNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadGoals() async {
    setState(() => _loading = true);
    try {
      final response = await _profileService.getHealthGoals();
      final progressResponse = await _profileService.getHealthGoalProgress();
      final goals = response.data;
      if (!mounted) {
        return;
      }
      if (!response.success || goals == null) {
        _showMessage(response.message.isEmpty ? '健康目标加载失败' : response.message);
        return;
      }
      _applyGoals(goals);
      if (progressResponse.success) {
        setState(() => _progress = progressResponse.data);
      }
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    final validationMessage = _validateGoalInputs();
    if (validationMessage != null) {
      _showMessage(validationMessage);
      return;
    }
    setState(() => _saving = true);
    try {
      final response = await _profileService.updateHealthGoals(
        HealthGoalModel(
          stepsTarget: _blankToNull(_stepsController.text),
          stepsNote: _blankToNull(_stepsNoteController.text),
          sleepTarget: _blankToNull(_sleepController.text),
          sleepNote: _blankToNull(_sleepNoteController.text),
          bloodPressureTarget: _blankToNull(_bloodPressureController.text),
          bloodPressureNote: _blankToNull(_bloodPressureNoteController.text),
        ),
      );
      final goals = response.data;
      if (!mounted) {
        return;
      }
      if (!response.success || goals == null) {
        _showMessage(response.message.isEmpty ? '健康目标保存失败' : response.message);
        return;
      }
      _applyGoals(goals);
      await _refreshProgress();
      _showMessage('健康目标已保存');
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _applyGoals(HealthGoalModel goals) {
    _stepsController.text = goals.stepsTarget ?? '';
    _stepsNoteController.text = goals.stepsNote ?? '';
    _sleepController.text = goals.sleepTarget ?? '';
    _sleepNoteController.text = goals.sleepNote ?? '';
    _bloodPressureController.text = goals.bloodPressureTarget ?? '';
    _bloodPressureNoteController.text = goals.bloodPressureNote ?? '';
  }

  Future<void> _refreshProgress() async {
    final response = await _profileService.getHealthGoalProgress();
    if (!mounted || !response.success) {
      return;
    }
    setState(() => _progress = response.data);
  }

  String? _blankToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _updateGoalText(TextEditingController controller, String value) {
    setState(() {
      if (controller.text != value) {
        controller.text = value;
        controller.selection = TextSelection.collapsed(offset: value.length);
      }
    });
  }

  String? _validateGoalInputs() {
    final stepsText = _stepsController.text.trim();
    if (stepsText.isEmpty) {
      return '请填写步数目标，例如 8000';
    }
    final steps = int.tryParse(stepsText);
    if (steps == null || steps < 1 || steps > 100000) {
      return '步数目标只能输入 1 到 100000 的整数';
    }

    final sleepText = _sleepController.text.trim();
    if (sleepText.isEmpty) {
      return '请填写睡眠目标，例如 7.5';
    }
    final sleep = double.tryParse(sleepText);
    if (sleep == null || sleep < 0.5 || sleep > 24) {
      return '睡眠目标只能输入 0.5 到 24 之间的数字';
    }

    final pressureText = _bloodPressureController.text.trim().replaceAll(
          '／',
          '/',
        );
    if (pressureText.isEmpty) {
      return '请填写血压目标，例如 140/90';
    }
    final pressureMatch =
        RegExp(r'^(\d{2,3})/(\d{2,3})$').firstMatch(pressureText);
    if (pressureMatch == null) {
      return '血压目标格式应为 收缩压/舒张压，例如 140/90';
    }
    final systolic = int.parse(pressureMatch.group(1)!);
    final diastolic = int.parse(pressureMatch.group(2)!);
    if (systolic < 60 ||
        systolic > 250 ||
        diastolic < 40 ||
        diastolic > 160 ||
        systolic <= diastolic) {
      return '血压目标范围不合理：收缩压 60-250，舒张压 40-160，且收缩压需大于舒张压';
    }
    _bloodPressureController.text = pressureText;
    return null;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return _ProfileDetailScaffold(
      title: '健康目标',
      subtitle: '跟踪每日运动、睡眠和健康指标',
      children: [
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else ...[
          _GoalProgressEditor(
            icon: Icons.directions_walk_rounded,
            color: AppColors.primary,
            fallbackLabel: '每日步数',
            targetLabel: '步数目标',
            targetHint: '例如 8000',
            targetHelper: '自定义范围：1-100000 的整数',
            targetController: _stepsController,
            progress: _progress?.steps,
            unitLabel: '步',
            options: const [
              _GoalTargetOption(label: '轻量 6000', value: '6000'),
              _GoalTargetOption(label: '标准 8000', value: '8000'),
              _GoalTargetOption(label: '积极 10000', value: '10000'),
            ],
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onTargetChanged: (value) =>
                _updateGoalText(_stepsController, value),
            onRefresh: _refreshProgress,
          ),
          const SizedBox(height: AppSpacing.md),
          _GoalProgressEditor(
            icon: Icons.bedtime_rounded,
            fallbackLabel: '睡眠时长',
            targetLabel: '睡眠目标',
            targetHint: '例如 7.5',
            targetHelper: '自定义范围：0.5-24 小时',
            targetController: _sleepController,
            progress: _progress?.sleep,
            unitLabel: '小时',
            options: const [
              _GoalTargetOption(label: '6.5 小时', value: '6.5'),
              _GoalTargetOption(label: '7.5 小时', value: '7.5'),
              _GoalTargetOption(label: '8 小时', value: '8'),
            ],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              LengthLimitingTextInputFormatter(5),
            ],
            color: AppColors.chartPurple,
            onTargetChanged: (value) =>
                _updateGoalText(_sleepController, value),
            onRefresh: _refreshProgress,
          ),
          const SizedBox(height: AppSpacing.md),
          _GoalProgressEditor(
            icon: Icons.monitor_heart_rounded,
            fallbackLabel: '血压管理',
            targetLabel: '血压目标',
            targetHint: '例如 140/90',
            targetHelper: '格式：收缩压/舒张压，范围 60-250/40-160',
            targetController: _bloodPressureController,
            progress: _progress?.bloodPressure,
            unitLabel: 'mmHg',
            options: const [
              _GoalTargetOption(label: '严格 120/80', value: '120/80'),
              _GoalTargetOption(label: '稳控 130/85', value: '130/85'),
              _GoalTargetOption(label: '常规 140/90', value: '140/90'),
            ],
            keyboardType: TextInputType.text,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
              LengthLimitingTextInputFormatter(7),
            ],
            color: AppColors.emergency,
            onTargetChanged: (value) =>
                _updateGoalText(_bloodPressureController, value),
            onRefresh: _refreshProgress,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: _loading || _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded),
          label: Text(_saving ? '保存中' : '保存目标'),
        ),
      ],
    );
  }
}

class _EmergencyContactsPage extends StatefulWidget {
  const _EmergencyContactsPage();

  @override
  State<_EmergencyContactsPage> createState() => _EmergencyContactsPageState();
}

class _EmergencyContactsPageState extends State<_EmergencyContactsPage> {
  final _emergencyService = EmergencyService();
  List<EmergencyContactModel> _contacts = const [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadContacts());
  }

  Future<void> _loadContacts() async {
    setState(() => _loading = true);
    try {
      final response = await _emergencyService.getContacts();
      if (!mounted) {
        return;
      }
      if (!response.success) {
        _showMessage(response.message.isEmpty ? '紧急联系人加载失败' : response.message);
        return;
      }
      setState(() => _contacts = response.data ?? const []);
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _addContact() async {
    final contact = await _showContactDialog(
      title: '添加联系人',
      contact:
          const _ContactDraft(name: '', relation: '', phone: '', priority: 1),
    );
    if (contact == null) {
      return;
    }
    await _saveContact(contact);
  }

  Future<void> _editContact(int index) async {
    final current = _contacts[index];
    final contact = await _showContactDialog(
      title: '编辑联系人',
      contact: _draftFromContact(current),
    );
    if (contact == null) {
      return;
    }
    await _saveContact(contact, id: current.id);
  }

  Future<void> _saveContact(_ContactDraft draft, {int? id}) async {
    if (draft.name.isEmpty || draft.phone.isEmpty) {
      _showMessage('请填写姓名和手机号');
      return;
    }
    setState(() => _saving = true);
    try {
      final contact = EmergencyContactModel(
        id: id ?? 0,
        name: draft.name,
        phone: draft.phone,
        relationship: draft.relation.isEmpty ? null : draft.relation,
        priority: draft.priority,
      );
      final response = id == null
          ? await _emergencyService.createContact(contact)
          : await _emergencyService.updateContact(contact);
      if (!mounted) {
        return;
      }
      if (!response.success || response.data == null) {
        _showMessage(response.message.isEmpty ? '紧急联系人保存失败' : response.message);
        return;
      }
      await _loadContacts();
      _showMessage('紧急联系人已保存');
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteContact(int index) async {
    final contact = _contacts[index];
    setState(() => _saving = true);
    try {
      final response = await _emergencyService.deleteContact(contact.id);
      if (!mounted) {
        return;
      }
      if (!response.success) {
        _showMessage(response.message.isEmpty ? '紧急联系人删除失败' : response.message);
        return;
      }
      await _loadContacts();
      _showMessage('紧急联系人已删除');
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  _ContactDraft _draftFromContact(EmergencyContactModel contact) {
    return _ContactDraft(
      name: contact.name,
      relation: contact.relationship ?? '',
      phone: contact.phone,
      priority: contact.priority <= 0 ? 1 : contact.priority,
    );
  }

  Future<_ContactDraft?> _showContactDialog({
    required String title,
    required _ContactDraft contact,
  }) async {
    var name = contact.name;
    var relation = contact.relation;
    var phone = contact.phone;
    var priority = contact.priority.toString();

    return showDialog<_ContactDraft>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: name,
                  decoration: const InputDecoration(labelText: '姓名'),
                  onChanged: (value) => name = value,
                ),
                TextFormField(
                  initialValue: relation,
                  decoration: const InputDecoration(labelText: '关系'),
                  onChanged: (value) => relation = value,
                ),
                TextFormField(
                  initialValue: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: '手机号'),
                  onChanged: (value) => phone = value,
                ),
                TextFormField(
                  initialValue: priority,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '优先级'),
                  onChanged: (value) => priority = value,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(
                  _ContactDraft(
                    name: name.trim(),
                    relation: relation.trim(),
                    phone: phone.trim(),
                    priority: int.tryParse(priority.trim()) ?? 1,
                  ),
                );
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return _ProfileDetailScaffold(
      title: '紧急联系人',
      subtitle: '管理 SOS 呼救时优先通知的人',
      children: [
        FilledButton.icon(
          onPressed: _loading || _saving ? null : _addContact,
          icon: const Icon(Icons.add_rounded),
          label: const Text('添加联系人'),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_contacts.isEmpty)
          const GlassCard(child: Text('还没有紧急联系人'))
        else
          for (var index = 0; index < _contacts.length; index++) ...[
            _ContactCard(
              contact: _contacts[index],
              onEdit: _saving ? null : () => _editContact(index),
              onDelete: _saving ? null : () => _deleteContact(index),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
      ],
    );
  }
}

class _DeviceSyncInteractivePage extends StatefulWidget {
  const _DeviceSyncInteractivePage();

  @override
  State<_DeviceSyncInteractivePage> createState() =>
      _DeviceSyncInteractivePageState();
}

class _DeviceSyncInteractivePageState
    extends State<_DeviceSyncInteractivePage> {
  final _deviceSyncService = DeviceSyncService();
  final _healthEventService = HealthEventService();
  final _heartRateController = TextEditingController();
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _bloodGlucoseController = TextEditingController();
  final _stepsController = TextEditingController();
  final _sleepHoursController = TextEditingController();
  DeviceSyncModel? _device;
  final List<DeviceSignalModel> _signals = [];
  bool _loading = true;
  bool _syncing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadDevice());
  }

  @override
  void dispose() {
    _heartRateController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _bloodGlucoseController.dispose();
    _stepsController.dispose();
    _sleepHoursController.dispose();
    super.dispose();
  }

  Future<void> _loadDevice() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _deviceSyncService.getCurrentDevice();
      if (!mounted) return;
      if (!response.success || response.data == null) {
        final message =
            response.message.isEmpty ? '设备状态加载失败' : response.message;
        setState(() => _error = message);
        _showMessage(message);
        return;
      }
      setState(() => _device = response.data);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
        _showMessage(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _mockSync() async {
    setState(() => _syncing = true);
    try {
      final response = await _deviceSyncService.mockSync();
      if (!mounted) return;
      if (!response.success || response.data == null) {
        _showMessage(response.message.isEmpty ? '模拟同步失败' : response.message);
        return;
      }
      _applyDevice(response.data!);
      _showMessage('模拟设备数据已同步');
      await _showDeviceRiskFeedback(response.data!);
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  Future<void> _sendSignal(String signalType) async {
    setState(() => _syncing = true);
    try {
      final response = await _deviceSyncService.sendSignal(
        signalType: signalType,
        payload: 'profile_device_sync_page',
      );
      if (!mounted) return;
      if (!response.success || response.data == null) {
        _showMessage(response.message.isEmpty ? '信号发送失败' : response.message);
        return;
      }
      _applyDevice(response.data!);
      _showMessage(response.data!.lastSignal?.message ?? '模拟信号已发送');
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  Future<void> _submitCustomMetrics() async {
    final validation = _validateCustomMetrics();
    if (validation != null) {
      _showMessage(validation);
      return;
    }
    setState(() => _syncing = true);
    try {
      final response = await _deviceSyncService.customSync(
        heartRate: _parseDouble(_heartRateController.text),
        systolic: _parseInt(_systolicController.text),
        diastolic: _parseInt(_diastolicController.text),
        bloodGlucose: _parseDouble(_bloodGlucoseController.text),
        steps: _parseInt(_stepsController.text),
        sleepHours: _parseDouble(_sleepHoursController.text),
      );
      if (!mounted) return;
      if (!response.success || response.data == null) {
        _showMessage(response.message.isEmpty ? '自定义数据同步失败' : response.message);
        return;
      }
      _applyDevice(response.data!);
      _clearCustomInputs();
      _showMessage('自定义手环数据已同步');
      await _showDeviceRiskFeedback(response.data!);
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  String? _validateCustomMetrics() {
    final heartRate = _parseDouble(_heartRateController.text);
    final systolic = _parseInt(_systolicController.text);
    final diastolic = _parseInt(_diastolicController.text);
    final bloodGlucose = _parseDouble(_bloodGlucoseController.text);
    final steps = _parseInt(_stepsController.text);
    final sleepHours = _parseDouble(_sleepHoursController.text);

    if (heartRate == null &&
        systolic == null &&
        diastolic == null &&
        bloodGlucose == null &&
        steps == null &&
        sleepHours == null) {
      return '请至少填写一项手环数据';
    }
    if (_hasText(_heartRateController.text) &&
        (heartRate == null || heartRate < 30 || heartRate > 220)) {
      return '心率范围应为 30-220 bpm';
    }
    if (systolic != null || diastolic != null) {
      if (systolic == null || diastolic == null) {
        return '血压需要同时填写收缩压和舒张压';
      }
      if (systolic < 40 ||
          systolic > 300 ||
          diastolic < 30 ||
          diastolic > 200 ||
          systolic <= diastolic) {
        return '血压范围不合理，请检查收缩压和舒张压';
      }
    }
    if (_hasText(_bloodGlucoseController.text) &&
        (bloodGlucose == null || bloodGlucose < 1 || bloodGlucose > 30)) {
      return '血糖范围应为 1-30 mmol/L';
    }
    if (_hasText(_stepsController.text) &&
        (steps == null || steps < 1 || steps > 100000)) {
      return '步数范围应为 1-100000 步';
    }
    if (_hasText(_sleepHoursController.text) &&
        (sleepHours == null || sleepHours < 0.5 || sleepHours > 24)) {
      return '睡眠范围应为 0.5-24 小时';
    }
    return null;
  }

  double? _parseDouble(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : double.tryParse(trimmed);
  }

  int? _parseInt(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : int.tryParse(trimmed);
  }

  bool _hasText(String value) => value.trim().isNotEmpty;

  void _clearCustomInputs() {
    _heartRateController.clear();
    _systolicController.clear();
    _diastolicController.clear();
    _bloodGlucoseController.clear();
    _stepsController.clear();
    _sleepHoursController.clear();
  }

  void _applyDevice(DeviceSyncModel device) {
    setState(() {
      _device = device;
      final signal = device.lastSignal;
      if (signal != null) {
        _signals.insert(0, signal);
        if (_signals.length > 5) {
          _signals.removeLast();
        }
      }
    });
  }

  Future<void> _showDeviceRiskFeedback(DeviceSyncModel device) async {
    if (device.riskAlert != null && device.riskAlert!.needsAttention) {
      await _openDeviceRiskFeedback(device, device.riskAlert!);
      return;
    }
    if (device.writtenRecordIds.isEmpty) {
      return;
    }

    HealthEventModel? event;
    try {
      event = await _healthEventService.waitForAnyRecordEvent(
        device.writtenRecordIds,
      );
    } catch (_) {
      return;
    }
    if (!mounted || event == null) {
      return;
    }

    await _openDeviceRiskFeedback(device, event);
  }

  Future<void> _openDeviceRiskFeedback(
    DeviceSyncModel device,
    HealthEventModel event,
  ) async {
    final action = await showHealthRiskDialog(context, event);
    if (!mounted || action == null || action == HealthRiskAction.later) {
      return;
    }

    final type = _recordTypeForDeviceEvent(device, event);
    final Widget page;
    if (action == HealthRiskAction.trend) {
      page = TrendPage(initialType: type);
    } else if (action == HealthRiskAction.sos) {
      page = const EmergencyPage();
    } else {
      return;
    }
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  HealthRecordType _recordTypeForDeviceEvent(
    DeviceSyncModel device,
    HealthEventModel event,
  ) {
    final index = device.writtenRecordIds.indexOf(event.healthRecordId);
    if (index >= 0 && index < device.writtenRecordTypes.length) {
      return HealthRecordTypeX.fromApiValue(device.writtenRecordTypes[index]);
    }
    return HealthRecordType.bloodPressure;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final device = _device;
    return _ProfileDetailScaffold(
      title: '设备同步',
      subtitle: '模拟可穿戴设备的数据同步与信号发送',
      children: [
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (device == null)
          _DeviceEmptyState(error: _error, onRetry: _loadDevice)
        else ...[
          _DeviceStatusCard(device: device),
          const SizedBox(height: AppSpacing.md),
          _DeviceActionPanel(
            busy: _syncing,
            onRefresh: _loadDevice,
            onMockSync: _mockSync,
            onPing: () => _sendSignal('ping'),
            onLocate: () => _sendSignal('locate'),
            onVibrate: () => _sendSignal('vibrate'),
          ),
          const SizedBox(height: AppSpacing.md),
          _DeviceCustomInputPanel(
            busy: _syncing,
            heartRateController: _heartRateController,
            systolicController: _systolicController,
            diastolicController: _diastolicController,
            bloodGlucoseController: _bloodGlucoseController,
            stepsController: _stepsController,
            sleepHoursController: _sleepHoursController,
            onSubmit: _submitCustomMetrics,
          ),
          const SizedBox(height: AppSpacing.md),
          _DeviceMetricGrid(metrics: device.metrics),
          const SizedBox(height: AppSpacing.md),
          _DeviceSignalLog(signals: _signals),
        ],
      ],
    );
  }
}

class _DeviceEmptyState extends StatelessWidget {
  const _DeviceEmptyState({required this.error, required this.onRetry});

  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('设备状态暂不可用', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            error == null || error!.isEmpty ? '请稍后重试' : error!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重新加载'),
          ),
        ],
      ),
    );
  }
}

class _DeviceStatusCard extends StatelessWidget {
  const _DeviceStatusCard({required this.device});

  final DeviceSyncModel device;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.chartBlue.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.watch_rounded,
                  color: AppColors.chartBlue,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.deviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '模拟设备 · ${_connectionLabel(device.connectionStatus)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _DetailRow(
            label: '连接状态',
            value: _connectionLabel(device.connectionStatus),
          ),
          _DetailRow(label: '最近同步', value: _formatTime(device.lastSyncAt)),
          const _DetailRow(label: '同步数据', value: '心率、血压、血糖'),
          _DetailRow(label: '电量', value: '${device.battery}%'),
        ],
      ),
    );
  }
}

class _DeviceActionPanel extends StatelessWidget {
  const _DeviceActionPanel({
    required this.busy,
    required this.onRefresh,
    required this.onMockSync,
    required this.onPing,
    required this.onLocate,
    required this.onVibrate,
  });

  final bool busy;
  final VoidCallback onRefresh;
  final VoidCallback onMockSync;
  final VoidCallback onPing;
  final VoidCallback onLocate;
  final VoidCallback onVibrate;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('模拟操作', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy ? null : onMockSync,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded),
                  label: const Text('模拟同步'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.filledTonal(
                tooltip: '刷新状态',
                onPressed: busy ? null : onRefresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _SignalButton(
                icon: Icons.sensors_rounded,
                label: '探测',
                onPressed: busy ? null : onPing,
              ),
              _SignalButton(
                icon: Icons.my_location_rounded,
                label: '定位',
                onPressed: busy ? null : onLocate,
              ),
              _SignalButton(
                icon: Icons.vibration_rounded,
                label: '震动',
                onPressed: busy ? null : onVibrate,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeviceCustomInputPanel extends StatelessWidget {
  const _DeviceCustomInputPanel({
    required this.busy,
    required this.heartRateController,
    required this.systolicController,
    required this.diastolicController,
    required this.bloodGlucoseController,
    required this.stepsController,
    required this.sleepHoursController,
    required this.onSubmit,
  });

  final bool busy;
  final TextEditingController heartRateController;
  final TextEditingController systolicController;
  final TextEditingController diastolicController;
  final TextEditingController bloodGlucoseController;
  final TextEditingController stepsController;
  final TextEditingController sleepHoursController;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '自定义手环数据',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '可只填写本次采集到的指标，提交后写入健康记录。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _DeviceMetricInput(
                  controller: heartRateController,
                  label: '心率',
                  suffix: 'bpm',
                  hint: '30-220',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _DeviceMetricInput(
                  controller: bloodGlucoseController,
                  label: '血糖',
                  suffix: 'mmol/L',
                  hint: '1-30',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    LengthLimitingTextInputFormatter(5),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _DeviceMetricInput(
                  controller: systolicController,
                  label: '收缩压',
                  suffix: 'mmHg',
                  hint: '40-300',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _DeviceMetricInput(
                  controller: diastolicController,
                  label: '舒张压',
                  suffix: 'mmHg',
                  hint: '30-200',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _DeviceMetricInput(
                  controller: stepsController,
                  label: '步数',
                  suffix: '步',
                  hint: '1-100000',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _DeviceMetricInput(
                  controller: sleepHoursController,
                  label: '睡眠',
                  suffix: '小时',
                  hint: '0.5-24',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    LengthLimitingTextInputFormatter(5),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : onSubmit,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_rounded),
              label: Text(busy ? '同步中' : '同步自定义数据'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceMetricInput extends StatelessWidget {
  const _DeviceMetricInput({
    required this.controller,
    required this.label,
    required this.suffix,
    required this.hint,
    required this.keyboardType,
    required this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;
  final String hint;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
      ),
    );
  }
}

class _SignalButton extends StatelessWidget {
  const _SignalButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _DeviceMetricGrid extends StatelessWidget {
  const _DeviceMetricGrid({required this.metrics});

  final List<DeviceMetricModel> metrics;

  @override
  Widget build(BuildContext context) {
    final visibleMetrics = metrics.isEmpty
        ? const [
            DeviceMetricModel(
              type: 'heart_rate',
              label: '心率',
              value: 78,
              unit: 'bpm',
            ),
          ]
        : metrics;
    return Column(
      children: [
        for (final metric in visibleMetrics) ...[
          _DeviceMetricTile(metric: metric),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _DeviceMetricTile extends StatelessWidget {
  const _DeviceMetricTile({required this.metric});

  final DeviceMetricModel metric;

  @override
  Widget build(BuildContext context) {
    final isWarning = metric.status == 'warning' || metric.status == 'danger';
    final color = isWarning ? AppColors.warning : AppColors.success;
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(_metricIcon(metric.type), color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              metric.label,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Text(
            metric.displayValue,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _DeviceSignalLog extends StatelessWidget {
  const _DeviceSignalLog({required this.signals});

  final List<DeviceSignalModel> signals;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('信号发送记录', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          if (signals.isEmpty)
            Text(
              '暂无信号记录',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
            )
          else
            for (final signal in signals) ...[
              _DetailRow(
                label: _signalLabel(signal.signalType),
                value: '${signal.status} · ${_formatTime(signal.sentAt)}',
              ),
              Text(
                signal.message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
        ],
      ),
    );
  }
}

IconData _metricIcon(String type) {
  return switch (type) {
    'blood_pressure' => Icons.monitor_heart_rounded,
    'blood_glucose' => Icons.water_drop_rounded,
    'heart_rate' => Icons.favorite_rounded,
    _ => Icons.insights_rounded,
  };
}

String _signalLabel(String type) {
  return switch (type) {
    'locate' => '定位信号',
    'vibrate' => '震动信号',
    'sync' => '同步信号',
    'custom' => '自定义信号',
    _ => '探测信号',
  };
}

String _connectionLabel(String status) {
  return switch (status) {
    'online' => '在线',
    'offline' => '离线',
    _ => '模拟在线',
  };
}

String _formatTime(DateTime? value) {
  if (value == null) {
    return '--';
  }
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final second = value.second.toString().padLeft(2, '0');
  return '$month-$day $hour:$minute:$second';
}

String _formatRelativeSyncTime(DateTime? value) {
  if (value == null) {
    return '--';
  }
  final difference = DateTime.now().difference(value);
  if (difference.inSeconds < 60) {
    return '刚刚';
  }
  if (difference.inMinutes < 60) {
    return '${difference.inMinutes} 分钟前';
  }
  if (difference.inHours < 24) {
    return '${difference.inHours} 小时前';
  }
  if (difference.inDays < 7) {
    return '${difference.inDays} 天前';
  }
  return _formatTime(value);
}

// ignore: unused_element
class _DeviceSyncPage extends StatelessWidget {
  const _DeviceSyncPage();

  @override
  Widget build(BuildContext context) {
    return const _ProfileDetailScaffold(
      title: '设备同步',
      subtitle: '查看可穿戴设备的数据同步状态',
      children: [
        _DetailSection(
          title: 'Apple Watch',
          rows: [
            _DetailRow(label: '连接状态', value: '在线'),
            _DetailRow(label: '最近同步', value: '进入新版设备同步页查看'),
            _DetailRow(label: '同步数据', value: '心率、睡眠、活动'),
            _DetailRow(label: '电量', value: '76%'),
          ],
        ),
        SizedBox(height: AppSpacing.md),
        _GoalCard(
          icon: Icons.sync_rounded,
          title: '自动同步',
          value: '已开启',
          progress: '后台每 15 分钟更新一次',
          color: AppColors.chartBlue,
        ),
      ],
    );
  }
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage();

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  final _settingsController = SettingsController();
  double _fontScale = 1;
  bool _notificationEnabled = true;
  bool _largeTouchTarget = false;
  bool _simpleMode = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
  }

  @override
  void dispose() {
    _settingsController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    await _settingsController.load();
    if (!mounted) {
      return;
    }
    final settings = _settingsController.settings;
    if (settings == null) {
      _showMessage(_settingsController.errorMessage ?? '设置加载失败');
      setState(() => _loading = false);
      return;
    }
    _applySettings(settings);
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final saved = await _settingsController.save(
      UserSettingModel(
        fontScale: _fontScale,
        notificationEnabled: _notificationEnabled,
        largeTouchTarget: _largeTouchTarget,
        simpleMode: _simpleMode,
      ),
    );
    if (!mounted) {
      return;
    }
    if (!saved || _settingsController.settings == null) {
      _showMessage(_settingsController.errorMessage ?? '设置保存失败');
      setState(() => _saving = false);
      return;
    }
    _applySettings(_settingsController.settings!);
    _showMessage('设置已保存');
    setState(() => _saving = false);
  }

  void _applySettings(UserSettingModel settings) {
    setState(() {
      _fontScale = settings.fontScale.clamp(0.85, 1.3).toDouble();
      _notificationEnabled = settings.notificationEnabled;
      _largeTouchTarget = settings.largeTouchTarget;
      _simpleMode = settings.simpleMode;
    });
  }

  void _applyRuntimePreview() {
    AppRuntimeSettings.instance.apply(
      UserSettingModel(
        fontScale: _fontScale,
        notificationEnabled: _notificationEnabled,
        largeTouchTarget: _largeTouchTarget,
        simpleMode: _simpleMode,
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return _ProfileDetailScaffold(
      title: '设置',
      subtitle: '调整字号、提醒和按钮触控偏好',
      children: [
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else ...[
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('字号大小', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '当前 ${(_fontScale * 100).round()}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                ),
                Slider(
                  value: _fontScale,
                  min: 0.85,
                  max: 1.3,
                  divisions: 9,
                  label: '${(_fontScale * 100).round()}%',
                  onChanged: (value) {
                    setState(() => _fontScale = value);
                    _applyRuntimePreview();
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '健康提醒和页面文字预览',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SettingsToggleRow(
                  value: _notificationEnabled,
                  title: const Text('健康提醒通知'),
                  subtitle: const Text('用药、复诊和异常指标提醒'),
                  icon: Icons.notifications_active_rounded,
                  onChanged: (value) {
                    setState(() => _notificationEnabled = value);
                    _applyRuntimePreview();
                  },
                ),
                _SettingsToggleRow(
                  value: _largeTouchTarget,
                  title: const Text('大按钮模式'),
                  subtitle: const Text('增大常用操作的点击区域'),
                  icon: Icons.touch_app_rounded,
                  onChanged: (value) {
                    setState(() => _largeTouchTarget = value);
                    _applyRuntimePreview();
                  },
                ),
                _SettingsToggleRow(
                  value: _simpleMode,
                  title: const Text('简洁模式'),
                  subtitle: const Text('减少次要信息，突出常用健康操作'),
                  icon: Icons.filter_alt_rounded,
                  onChanged: (value) {
                    setState(() => _simpleMode = value);
                    _applyRuntimePreview();
                  },
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: _loading || _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded),
          label: Text(_saving ? '保存中' : '保存设置'),
        ),
      ],
    );
  }
}

// ignore: unused_element
class _SettingsPrototypeCard extends StatelessWidget {
  const _SettingsPrototypeCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.chartPurple.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.storage_rounded,
              color: AppColors.chartPurple,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('持久化原型', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'GET/PUT /api/profile/settings -> user_setting',
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

class _SettingsToggleRow extends StatelessWidget {
  const _SettingsToggleRow({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onChanged,
  });

  final bool value;
  final Widget title;
  final Widget subtitle;
  final IconData icon;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final largeTouchTarget = AppRuntimeSettings.instance.largeTouchTarget;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: largeTouchTarget ? AppSpacing.lg : AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.primary,
            size: largeTouchTarget ? 28 : 24,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DefaultTextStyle.merge(
                  style: Theme.of(context).textTheme.titleSmall,
                  child: title,
                ),
                const SizedBox(height: AppSpacing.xxs),
                DefaultTextStyle.merge(
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                  child: subtitle,
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: largeTouchTarget ? 1.12 : 1,
            child: Switch(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

class _ProfileDetailScaffold extends StatelessWidget {
  const _ProfileDetailScaffold({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title)),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppGradients.page,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 36),
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: AppSpacing.xl),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.rows,
  });

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          for (final row in rows) row,
        ],
      ),
    );
  }
}

class _EditableField extends StatelessWidget {
  const _EditableField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.prefixIcon,
    this.allowClear = false,
    this.validator,
    this.maxLength,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final IconData? prefixIcon;
  final bool allowClear;
  final FormFieldValidator<String>? validator;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        maxLength: maxLength,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
          suffixIcon: allowClear && controller.text.isNotEmpty
              ? IconButton(
                  tooltip: '清除',
                  onPressed: controller.clear,
                  icon: const Icon(Icons.close_rounded),
                )
              : null,
        ),
      ),
    );
  }
}

class _GenderDropdown extends StatelessWidget {
  const _GenderDropdown({required this.controller});

  static const List<String> _options = ['男', '女'];

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final current = controller.text.trim();
    final selected = _options.contains(current) ? current : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: DropdownButtonFormField<String>(
        key: ValueKey(selected),
        initialValue: selected,
        items: _options
            .map(
              (value) => DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              ),
            )
            .toList(),
        onChanged: (value) {
          controller.text = value ?? '';
        },
        decoration: InputDecoration(
          labelText: '性别',
          prefixIcon: const Icon(Icons.wc_rounded),
          suffixIcon: selected == null
              ? null
              : IconButton(
                  tooltip: '清除',
                  onPressed: controller.clear,
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.progress,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final String progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  progress,
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

class _GoalTargetOption {
  const _GoalTargetOption({required this.label, required this.value});

  final String label;
  final String value;
}

class _GoalProgressEditor extends StatelessWidget {
  const _GoalProgressEditor({
    required this.icon,
    required this.fallbackLabel,
    required this.targetLabel,
    required this.targetHint,
    required this.targetHelper,
    required this.targetController,
    required this.unitLabel,
    required this.options,
    required this.color,
    required this.onTargetChanged,
    required this.onRefresh,
    this.progress,
    this.keyboardType,
    this.inputFormatters,
  });

  final IconData icon;
  final String fallbackLabel;
  final String targetLabel;
  final String targetHint;
  final String targetHelper;
  final TextEditingController targetController;
  final String unitLabel;
  final List<_GoalTargetOption> options;
  final HealthGoalProgressItemModel? progress;
  final Color color;
  final ValueChanged<String> onTargetChanged;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final item = progress;
    final value = item?.progress ?? 0;
    final currentTarget = targetController.text.trim();
    final presetSelected =
        options.any((option) => option.value == currentTarget);
    final customSelected = currentTarget.isEmpty || !presetSelected;
    final visibleTarget =
        currentTarget.isEmpty ? '请选择目标' : '$currentTarget $unitLabel';
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item?.label ?? fallbackLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      item?.status ?? '等待记录',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: '刷新进度',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _GoalProgressValue(
                  label: '当前',
                  value: item?.currentText ?? '--',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _GoalProgressValue(
                  label: '当前选择',
                  value: visibleTarget,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.12),
              color: color,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${(value * 100).round()}%',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            targetLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final option in options)
                ChoiceChip(
                  label: Text(option.label),
                  selected: currentTarget == option.value,
                  onSelected: (_) => onTargetChanged(option.value),
                ),
              ChoiceChip(
                label: const Text('自定义'),
                selected: customSelected,
                onSelected: (_) {
                  if (!customSelected) {
                    onTargetChanged('');
                  }
                },
              ),
            ],
          ),
          if (customSelected || currentTarget.isEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: targetController,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              onChanged: onTargetChanged,
              decoration: InputDecoration(
                labelText: '自定义$targetLabel',
                hintText: targetHint,
                helperText: targetHelper,
                prefixIcon: const Icon(Icons.edit_rounded),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GoalProgressValue extends StatelessWidget {
  const _GoalProgressValue({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _EditableGoalCard extends StatelessWidget {
  const _EditableGoalCard({
    required this.icon,
    required this.title,
    required this.valueController,
    required this.noteController,
    required this.color,
  });

  final IconData icon;
  final String title;
  final TextEditingController valueController;
  final TextEditingController noteController;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: valueController,
                  decoration: const InputDecoration(labelText: '目标值'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: '执行说明'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactDraft {
  const _ContactDraft({
    required this.name,
    required this.relation,
    required this.phone,
    required this.priority,
  });

  final String name;
  final String relation;
  final String phone;
  final int priority;
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.contact,
    required this.onEdit,
    required this.onDelete,
  });

  final EmergencyContactModel contact;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  String get _relationship {
    final relationship = contact.relationship;
    return relationship == null || relationship.trim().isEmpty
        ? '未填写关系'
        : relationship.trim();
  }

  String get _priorityLabel {
    return contact.priority <= 0 ? '普通联系人' : '第 ${contact.priority} 联系人';
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.emergency.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.contact_phone_rounded,
              color: AppColors.emergency,
              size: 23,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.name,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '$_relationship · ${contact.phone}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  _priorityLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.emergency,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '编辑联系人',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded),
          ),
          IconButton(
            tooltip: '删除联系人',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

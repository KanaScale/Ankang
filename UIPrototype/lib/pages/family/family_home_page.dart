import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../models/family_models.dart';
import '../../routes/route_names.dart';
import '../../services/care_mode_service.dart';
import '../../services/family_service.dart';
import '../../widgets/common/empty_view.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/loading_view.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ios_bottom_navigation.dart';
import 'family_agent_page.dart';
import 'family_bind_page.dart';
import 'family_patient_detail_page.dart';

class FamilyHomePage extends StatefulWidget {
  const FamilyHomePage({super.key, this.service});

  final FamilyService? service;

  @override
  State<FamilyHomePage> createState() => _FamilyHomePageState();
}

class _FamilyHomePageState extends State<FamilyHomePage> {
  late final FamilyService _service;
  var _patients = <BoundPatientModel>[];
  var _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? FamilyService();
    unawaited(_loadPatients());
  }

  Future<void> _loadPatients() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final response = await _service.getBoundPatients();
      if (!mounted) return;
      setState(() {
        _patients = response.data ?? const <BoundPatientModel>[];
        _errorMessage = response.success
            ? null
            : response.message.isEmpty
                ? '家庭照护数据加载失败'
                : response.message;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FamilyCareSettingsPage(service: _service),
      ),
    );
    if (mounted && CareModeService.isCaregiver) {
      await _loadPatients();
    }
  }

  void _openPatient(BoundPatientModel patient) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            FamilyPatientDetailPage(patient: patient, service: _service),
      ),
    );
  }

  void _openAgent(BoundPatientModel patient) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FamilyAgentPage(patient: patient, service: _service),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      appBar: AppBar(
        title: const Text('家庭照护'),
        actions: [
          IconButton(
            tooltip: '家庭照护设置',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadPatients,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              112,
            ),
            children: [
              Text(
                '我照护的家人',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_loading)
                const SizedBox(
                  height: 300,
                  child: LoadingView(message: '正在加载家庭照护'),
                )
              else if (_errorMessage != null)
                ErrorView(message: _errorMessage!, onRetry: _loadPatients)
              else if (_patients.isEmpty)
                EmptyView(
                  title: '暂无绑定家人',
                  message: '请先在家庭照护设置中绑定被照护者。',
                  action: OutlinedButton.icon(
                    onPressed: _openSettings,
                    icon: const Icon(Icons.settings_rounded),
                    label: const Text('前往家庭照护设置'),
                  ),
                )
              else
                ..._patients.map(
                  (patient) => _BoundPatientTile(
                    patient: patient,
                    onTap: () => _openPatient(patient),
                    onAgent: () => _openAgent(patient),
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar:
          const IosBottomNavigation(currentRoute: RouteNames.family),
    );
  }
}

class FamilyCareSettingsPage extends StatefulWidget {
  const FamilyCareSettingsPage({super.key, this.service});

  final FamilyService? service;

  @override
  State<FamilyCareSettingsPage> createState() =>
      _FamilyCareSettingsPageState();
}

class _FamilyCareSettingsPageState extends State<FamilyCareSettingsPage> {
  late final FamilyService _service;
  var _patients = <BoundPatientModel>[];
  FamilyInviteModel? _invite;
  var _loading = true;
  var _creatingInvite = false;
  var _switchingMode = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? FamilyService();
    if (CareModeService.isCaregiver) {
      unawaited(_loadPatients());
    } else {
      _loading = false;
    }
  }

  Future<void> _switchMode(CareMode mode) async {
    if (_switchingMode || mode == CareModeService.mode.value) return;
    setState(() => _switchingMode = true);
    try {
      await CareModeService.selectMode(mode);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        mode == CareMode.caregiver ? RouteNames.family : RouteNames.home,
        (route) => false,
      );
    } finally {
      if (mounted) setState(() => _switchingMode = false);
    }
  }

  Future<void> _loadPatients() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final response = await _service.getBoundPatients();
      if (!mounted) return;
      if (!response.success) {
        setState(() {
          _errorMessage =
              response.message.isEmpty ? '家庭照护数据加载失败' : response.message;
          _loading = false;
        });
        return;
      }
      setState(() {
        _patients = response.data ?? const <BoundPatientModel>[];
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _createInvite() async {
    if (_creatingInvite) return;
    setState(() => _creatingInvite = true);
    try {
      final response = await _service.createInvite();
      if (!mounted) return;
      if (!response.success || response.data == null) {
        _showMessage(response.message.isEmpty ? '绑定码生成失败' : response.message);
        return;
      }
      setState(() => _invite = response.data);
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _creatingInvite = false);
    }
  }

  Future<void> _openBind() async {
    final bound = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => FamilyBindPage(service: _service)),
    );
    if (bound == true && mounted) {
      await _loadPatients();
    }
  }

  Future<void> _unbind(BoundPatientModel patient) async {
    try {
      final response = await _service.unbindPatient(patient.patientUserId);
      if (!mounted) return;
      if (!response.success) {
        _showMessage(response.message.isEmpty ? '解除绑定失败' : response.message);
        return;
      }
      setState(() => _patients.removeWhere(
            (item) => item.patientUserId == patient.patientUserId,
          ));
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CareMode>(
      valueListenable: CareModeService.mode,
      builder: (context, mode, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('家庭照护'),
        ),
        body: SafeArea(
          bottom: false,
          child: mode == CareMode.patient
              ? ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    _CareModeCard(
                      mode: mode,
                      switching: _switchingMode,
                      onSelected: _switchMode,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _InviteCard(
                      invite: _invite,
                      creating: _creatingInvite,
                      onCreateInvite: _createInvite,
                    ),
                  ],
                )
              : RefreshIndicator(
                  onRefresh: _loadPatients,
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      _CareModeCard(
                        mode: mode,
                        switching: _switchingMode,
                        onSelected: _switchMode,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _CaregiverBindingCard(onBind: _openBind),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        '已绑定关系',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (_loading)
                        const SizedBox(
                          height: 300,
                          child: LoadingView(message: '正在加载家庭照护'),
                        )
                      else if (_errorMessage != null)
                        ErrorView(
                          message: _errorMessage!,
                          onRetry: _loadPatients,
                        )
                      else if (_patients.isEmpty)
                        EmptyView(
                          title: '暂无绑定关系',
                          action: OutlinedButton.icon(
                            onPressed: _openBind,
                            icon: const Icon(Icons.add_link_rounded),
                            label: const Text('输入绑定码'),
                          ),
                        )
                      else
                        ..._patients.map(
                          (patient) => _BoundPatientTile(
                            patient: patient,
                            relationOnly: true,
                            onUnbind: () => _unbind(patient),
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

class _CareModeCard extends StatelessWidget {
  const _CareModeCard({
    required this.mode,
    required this.switching,
    required this.onSelected,
  });

  final CareMode mode;
  final bool switching;
  final ValueChanged<CareMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '当前版本',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            mode == CareMode.patient
                ? '病人版：管理自己的健康数据，并授权家属照护。'
                : '家属版：绑定病人账号，查看对方授权的健康数据。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final useVerticalLayout =
                  MediaQuery.textScalerOf(context).scale(1) > 1.15 ||
                      constraints.maxWidth < 300;
              final patientButton = _ModeButton(
                key: const ValueKey('care_mode_patient_button'),
                label: '病人版',
                icon: Icons.monitor_heart_rounded,
                selected: mode == CareMode.patient,
                enabled: !switching,
                onTap: () => onSelected(CareMode.patient),
              );
              final caregiverButton = _ModeButton(
                key: const ValueKey('care_mode_caregiver_button'),
                label: '家属版',
                icon: Icons.family_restroom_rounded,
                selected: mode == CareMode.caregiver,
                enabled: !switching,
                onTap: () => onSelected(CareMode.caregiver),
              );
              if (useVerticalLayout) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    patientButton,
                    const SizedBox(height: AppSpacing.sm),
                    caregiverButton,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: patientButton),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: caregiverButton),
                ],
              );
            },
          ),
          if (switching) ...[
            const SizedBox(height: AppSpacing.md),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return selected
        ? FilledButton.tonalIcon(
            onPressed: null,
            icon: Icon(icon),
            label: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          )
        : OutlinedButton.icon(
            onPressed: enabled ? onTap : null,
            icon: Icon(icon),
            label: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
  }
}

class _CaregiverBindingCard extends StatelessWidget {
  const _CaregiverBindingCard({required this.onBind});

  final VoidCallback onBind;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '绑定被照护者',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '绑定码由病人生成。请向病人获取绑定码，再由家属在此输入。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: onBind,
            icon: const Icon(Icons.add_link_rounded),
            label: const Text('输入绑定码'),
          ),
        ],
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.invite,
    required this.creating,
    required this.onCreateInvite,
  });

  final FamilyInviteModel? invite;
  final bool creating;
  final VoidCallback onCreateInvite;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: const Icon(Icons.verified_user_rounded,
                    color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '生成家庭照护绑定码',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '由病人生成，并将绑定码提供给家属输入。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (invite != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.warmSurface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      invite!.inviteCode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    _formatTime(invite!.expireAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: creating ? null : onCreateInvite,
            icon: creating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.key_rounded),
            label: Text(
              creating
                  ? '生成中'
                  : invite == null
                      ? '生成绑定码'
                      : '刷新绑定码',
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${twoDigits(time.hour)}:${twoDigits(time.minute)} 过期';
  }
}

class _BoundPatientTile extends StatelessWidget {
  const _BoundPatientTile({
    required this.patient,
    this.relationOnly = false,
    this.onTap,
    this.onAgent,
    this.onUnbind,
  });

  final BoundPatientModel patient;
  final bool relationOnly;
  final VoidCallback? onTap;
  final VoidCallback? onAgent;
  final VoidCallback? onUnbind;

  @override
  Widget build(BuildContext context) {
    final color = _riskColor(patient.riskLevel);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: GlassCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.elderly_rounded, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.patientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      relationOnly
                          ? '绑定关系：${_relationLabel(patient.relationType)}'
                          : '${_relationLabel(patient.relationType)} · '
                              '${_riskLabel(patient.riskLevel)} · '
                              '${_formatDate(patient.lastUpdateTime)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiary,
                          ),
                    ),
                  ],
                ),
              ),
              if (onAgent != null)
                IconButton(
                  tooltip: '咨询 Agent',
                  onPressed: onAgent,
                  icon: const Icon(Icons.smart_toy_rounded),
                ),
              if (onUnbind != null)
                IconButton(
                  tooltip: '解除绑定',
                  onPressed: onUnbind,
                  icon: const Icon(Icons.link_off_rounded),
                ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _riskColor(String riskLevel) {
    return switch (riskLevel) {
      'high' => AppColors.emergency,
      'medium' => AppColors.warning,
      'low' => AppColors.success,
      _ => AppColors.textTertiary,
    };
  }

  String _riskLabel(String riskLevel) {
    return switch (riskLevel) {
      'high' => '高风险',
      'medium' => '需关注',
      'low' => '平稳',
      _ => '暂无记录',
    };
  }

  String _relationLabel(String value) {
    return switch (value) {
      'son' => '儿子',
      'daughter' => '女儿',
      'spouse' => '配偶',
      'parent' => '父母',
      _ => '家属',
    };
  }

  String _formatDate(DateTime? time) {
    if (time == null) return '暂无更新';
    return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

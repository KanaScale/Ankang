import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../models/family_models.dart';
import '../../routes/route_names.dart';
import '../../services/family_service.dart';
import '../../widgets/care_mode_switch.dart';
import '../../widgets/common/empty_view.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/loading_view.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ios_bottom_navigation.dart';
import 'family_bind_page.dart';
import 'family_patient_detail_page.dart';

class FamilyHealthPage extends StatefulWidget {
  const FamilyHealthPage({super.key, this.service});

  final FamilyService? service;

  @override
  State<FamilyHealthPage> createState() => _FamilyHealthPageState();
}

class _FamilyHealthPageState extends State<FamilyHealthPage> {
  late final FamilyService _service;
  var _patients = <BoundPatientModel>[];
  var _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? FamilyService();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final response = await _service.getBoundPatients();
      if (!mounted) {
        return;
      }
      if (!response.success) {
        setState(() {
          _patients = const [];
          _errorMessage =
              response.message.isEmpty ? '家庭照护数据加载失败' : response.message;
          _loading = false;
        });
        return;
      }
      setState(() {
        _patients = response.data ?? const [];
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _patients = const [];
        _errorMessage = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openBind() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => FamilyBindPage(service: _service)),
    );
    if (mounted) {
      await _loadPatients();
    }
  }

  void _openPatient(BoundPatientModel patient) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FamilyPatientDetailPage(
          patient: patient,
          service: _service,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('家属版健康数据'),
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadPatients,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 112),
            children: [
              const CaregiverModeStatusBanner(),
              const SizedBox(height: AppSpacing.lg),
              if (_loading)
                const SizedBox(height: 420, child: LoadingView())
              else if (_errorMessage != null)
                ErrorView(message: _errorMessage!, onRetry: _loadPatients)
              else if (_patients.isEmpty)
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.62,
                  child: EmptyView(
                    title: '还未绑定病人',
                    message: '绑定病人账号后，这里会显示对方授权共享的健康摘要、记录和趋势。',
                    action: OutlinedButton.icon(
                      onPressed: _openBind,
                      icon: const Icon(Icons.add_link_rounded),
                      label: const Text('输入绑定码'),
                    ),
                  ),
                )
              else ...[
                Text(
                  '选择被照护者',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '家属版只读取已绑定病人的健康数据，不能新增、修改或删除。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.lg),
                ..._patients.map(
                  (patient) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _FamilyPatientDataTile(
                      patient: patient,
                      onTap: () => _openPatient(patient),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar:
          const IosBottomNavigation(currentRoute: RouteNames.health),
    );
  }
}

class _FamilyPatientDataTile extends StatelessWidget {
  const _FamilyPatientDataTile({
    required this.patient,
    required this.onTap,
  });

  final BoundPatientModel patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.greenSurface,
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: AppColors.primary,
              ),
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
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${_relationLabel(patient.relationType)} · 风险 ${_riskLabel(patient.riskLevel)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }

  String _relationLabel(String value) {
    return switch (value) {
      'son' => '儿子',
      'daughter' => '女儿',
      'spouse' => '配偶',
      'parent' => '父母',
      'father' => '父亲',
      'mother' => '母亲',
      _ => '家属',
    };
  }

  String _riskLabel(String value) {
    return switch (value) {
      'high' => '高',
      'medium' => '中',
      'low' => '低',
      _ => '未知',
    };
  }
}

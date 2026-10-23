import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../models/family_models.dart';
import '../../routes/route_names.dart';
import '../../services/family_service.dart';
import '../../widgets/common/empty_view.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/loading_view.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ios_bottom_navigation.dart';
import 'family_agent_page.dart';
import 'family_bind_page.dart';

class FamilyAgentEntryPage extends StatefulWidget {
  const FamilyAgentEntryPage({super.key, this.service});

  final FamilyService? service;

  @override
  State<FamilyAgentEntryPage> createState() => _FamilyAgentEntryPageState();
}

class _FamilyAgentEntryPageState extends State<FamilyAgentEntryPage> {
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
              response.message.isEmpty ? '照护对象加载失败' : response.message;
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

  void _openAgent(BoundPatientModel patient) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FamilyAgentPage(
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
      appBar: AppBar(title: const Text('家属版 Agent')),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadPatients,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 112),
            children: [
              Text(
                '选择咨询对象',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Agent 会基于被照护者授权共享的健康数据回答家属问题。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_loading)
                const SizedBox(height: 420, child: LoadingView())
              else if (_errorMessage != null)
                ErrorView(message: _errorMessage!, onRetry: _loadPatients)
              else if (_patients.isEmpty)
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.58,
                  child: EmptyView(
                    title: '还未绑定病人',
                    message: '绑定病人账号后，可以在这里基于对方健康数据咨询 Agent。',
                    action: OutlinedButton.icon(
                      onPressed: _openBind,
                      icon: const Icon(Icons.add_link_rounded),
                      label: const Text('输入绑定码'),
                    ),
                  ),
                )
              else
                ..._patients.map(
                  (patient) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _AgentPatientTile(
                      patient: patient,
                      onTap: () => _openAgent(patient),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar:
          const IosBottomNavigation(currentRoute: RouteNames.familyAgent),
    );
  }
}

class _AgentPatientTile extends StatelessWidget {
  const _AgentPatientTile({
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
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
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
                    '照护咨询 · 血压、用药、趋势和风险问题',
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
}

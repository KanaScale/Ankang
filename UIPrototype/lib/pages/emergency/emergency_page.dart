import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../app/design_tokens.dart';
import '../../models/base_response.dart';
import '../../models/emergency_contact_model.dart';
import '../../models/emergency_dispatch_attempt_model.dart';
import '../../models/emergency_event_model.dart';
import '../../models/local_sos_event_model.dart';
import '../../models/nearby_hospital_model.dart';
import '../../models/sos_device_model.dart';
import '../../routes/route_names.dart';
import '../../services/api_client.dart';
import '../../services/emergency_service.dart';
import '../../services/emergency_contact_offline_repository.dart';
import '../../services/offline_session_coordinator.dart';
import '../../services/profile_service.dart';
import '../../services/sos_device_service.dart';
import '../../services/sos_preview_builder.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/loading_view.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ios_bottom_navigation.dart';
import '../../widgets/pressable_scale.dart';
import '../../widgets/section_title.dart';

/// SOS 紧急求助页 — 一键记录求助事件并展示后端联系人。
class EmergencyPage extends StatefulWidget {
  const EmergencyPage({
    super.key,
    this.service,
    this.deviceService,
    this.profileService,
  });

  /// 便于 widget 测试注入可控实现；生产环境默认使用真实 API Service。
  final EmergencyService? service;
  final SosDeviceService? deviceService;
  final ProfileService? profileService;

  @override
  State<EmergencyPage> createState() => _EmergencyPageState();
}

class _EmergencyPageState extends State<EmergencyPage>
    with WidgetsBindingObserver {
  late final EmergencyService _service;
  late final EmergencyContactOfflineRepository _contactRepository;
  late final SosDeviceService _deviceService;
  late final ProfileService _profileService;
  final List<EmergencyContactModel> _contacts = [];
  final List<NearbyHospitalModel> _nearbyHospitals = [];
  bool _loadingContacts = true;
  bool _loadingHospitals = false;
  bool _submittingSos = false;
  bool _loadingReadiness = true;
  bool _requestingPermissions = false;
  bool _preparingPreview = false;
  String? _contactsError;
  String? _hospitalsError;
  EmergencyEventModel? _lastEvent;
  SosDeviceReadiness? _readiness;
  SosLocationResult? _previewLocation;
  DateTime? _previewTriggeredAt;
  String? _previewMessage;
  String _displayName = '用户';
  String? _dispatchEventId;
  List<EmergencyDispatchAttemptModel> _dispatchAttempts = const [];
  Timer? _dispatchPollTimer;
  int _dispatchPollCount = 0;
  LocalSosEventModel? _localEvent;
  bool _syncingCloud = false;
  String? _syncError;
  bool _offerEmergencyNumber = false;
  bool _emergencyPromptShown = false;

  OfflineSessionSnapshot get _session =>
      OfflineSessionCoordinator.session.value;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    OfflineSessionCoordinator.session.addListener(_handleSessionChanged);
    _service = widget.service ?? EmergencyService();
    _contactRepository = EmergencyContactOfflineRepository(remote: _service);
    _deviceService = widget.deviceService ?? const SosDeviceService();
    _profileService = widget.profileService ?? ProfileService();
    _loadContacts();
    _loadReadiness();
    _loadDisplayName();
    if (_session.ownerUserId != null) {
      _restoreLocalSosState();
    }
  }

  void _handleSessionChanged() {
    _dispatchPollTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _lastEvent = null;
      _previewLocation = null;
      _previewTriggeredAt = null;
      _previewMessage = null;
      _dispatchEventId = null;
      _dispatchAttempts = const [];
      _localEvent = null;
      _syncingCloud = false;
      _syncError = null;
      _offerEmergencyNumber = false;
      _emergencyPromptShown = false;
    });
    if (_session.ownerUserId != null) {
      unawaited(_loadContacts());
      unawaited(_loadDisplayName());
      unawaited(_restoreLocalSosState());
    }
  }

  Future<void> _loadDisplayName() async {
    final sessionAtStart = _session;
    final ownerUserId = sessionAtStart.ownerUserId;
    if (ownerUserId == null) return;
    try {
      final response = await _profileService.getCurrentUser();
      final user = response.data;
      if (!mounted ||
          !_session.matches(ownerUserId, sessionAtStart.generation) ||
          !response.success ||
          user == null) {
        return;
      }
      final nickname = user.nickname?.trim();
      setState(() {
        _displayName = nickname?.isNotEmpty == true ? nickname! : user.username;
      });
    } catch (_) {
      // 昵称不可用不影响 SOS 降级流程。
    }
  }

  Future<void> _loadReadiness() async {
    if (mounted) setState(() => _loadingReadiness = true);
    final readiness = await _deviceService.checkReadiness();
    if (!mounted) return;
    setState(() {
      _readiness = readiness;
      _loadingReadiness = false;
    });
  }

  Future<void> _requestPermissions() async {
    if (_requestingPermissions) return;
    setState(() => _requestingPermissions = true);
    try {
      final readiness = await _deviceService.requestPermissions();
      if (mounted) setState(() => _readiness = readiness);
    } finally {
      if (mounted) setState(() => _requestingPermissions = false);
    }
  }

  Future<void> _loadNearbyHospitals() async {
    setState(() {
      _loadingHospitals = true;
      _hospitalsError = null;
    });
    try {
      final location = await _deviceService.resolveLocation();
      if (!location.available) {
        throw const ApiException('无法获取当前位置，请开启定位权限和定位服务后重试');
      }
      final response = await _service.getNearbyHospitals(
        latitude: location.latitude!,
        longitude: location.longitude!,
      );
      if (!response.success || response.data == null) {
        throw ApiException(response.message);
      }
      if (!mounted) return;
      setState(() {
        _nearbyHospitals
          ..clear()
          ..addAll(response.data!);
        _loadingHospitals = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingHospitals = false;
        _hospitalsError = _messageFor(error);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    OfflineSessionCoordinator.session.removeListener(_handleSessionChanged);
    _dispatchPollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _dispatchEventId != null) {
      unawaited(_refreshDispatchSnapshot());
      unawaited(_syncPendingLocalEvents());
    }
  }

  Future<void> _loadContacts() async {
    final sessionAtStart = _session;
    final ownerUserId = sessionAtStart.ownerUserId;
    if (ownerUserId == null) {
      if (mounted) {
        setState(() {
          _contacts.clear();
          _loadingContacts = false;
          _contactsError = null;
        });
      }
      return;
    }
    setState(() {
      _loadingContacts = true;
      _contactsError = null;
    });
    try {
      final cached = await _contactRepository.cached(ownerUserId);
      if (cached != null && mounted && _session.matches(ownerUserId, sessionAtStart.generation)) {
        setState(() { _contacts..clear()..addAll(cached); _loadingContacts = false; });
      }
      final response = await _contactRepository.get(ownerUserId);
      if (!response.success || response.data == null) {
        throw ApiException(response.message);
      }
      if (!mounted ||
          !_session.matches(ownerUserId, sessionAtStart.generation)) {
        return;
      }
      setState(() {
        _contacts
          ..clear()
          ..addAll(response.data!);
        _loadingContacts = false;
      });
    } catch (error) {
      if (!mounted ||
          !_session.matches(ownerUserId, sessionAtStart.generation)) {
        return;
      }
      setState(() {
        _loadingContacts = false;
        _contactsError = _messageFor(error);
      });
    }
  }

  Future<void> _triggerSos() async {
    if (_submittingSos) return;
    final sessionAtStart = _session;
    final ownerUserId = sessionAtStart.ownerUserId;
    if (ownerUserId == null || ownerUserId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登录身份无效，请重新登录后再发起 SOS。')),
      );
      return;
    }
    setState(() => _submittingSos = true);
    final triggeredAt = DateTime.now();
    final clientEventId = 'sos-${triggeredAt.microsecondsSinceEpoch}';
    var localEvent = LocalSosEventModel(
      ownerUserId: ownerUserId,
      clientEventId: clientEventId,
      triggeredAt: triggeredAt,
      locationSource: 'unavailable',
      message: '用户确认发起紧急求助',
      syncPending: true,
      executionState: SosExecutionState.prepared,
      contactSnapshot: _contacts.map((contact) => contact.toJson()).toList(),
    );
    try {
      await _deviceService.saveLocalSosEvent(localEvent);
      if (!_session.matches(ownerUserId, sessionAtStart.generation)) {
        return;
      }
      if (mounted) {
        setState(() {
          _localEvent = localEvent;
          _dispatchEventId = clientEventId;
          _dispatchAttempts = const [];
          _syncError = null;
          _offerEmergencyNumber = _primaryContact == null;
          _emergencyPromptShown = false;
        });
      }
      final preview = await _resolvePreview(
        triggeredAt: triggeredAt,
        sessionAtStart: sessionAtStart,
      );
      if (!_session.matches(ownerUserId, sessionAtStart.generation)) return;
      final location = preview.location;
      localEvent = LocalSosEventModel(
        ownerUserId: ownerUserId,
        clientEventId: clientEventId,
        triggeredAt: triggeredAt,
        latitude: location.latitude,
        longitude: location.longitude,
        accuracyMeters: location.accuracyMeters,
        locationSource: location.source,
        message: _previewMessage!,
        syncPending: true,
        executionState: SosExecutionState.prepared,
        contactSnapshot: _contacts.map((contact) => contact.toJson()).toList(),
      );
      await _deviceService.saveLocalSosEvent(localEvent);
      final attempts = await _deviceService.dispatchSos(
        ownerUserId: ownerUserId,
        clientEventId: clientEventId,
        message: localEvent.message,
        contacts: _contacts,
        event: localEvent,
      );
      if (!_session.matches(ownerUserId, sessionAtStart.generation)) return;
      if (mounted) {
        setState(() {
          _localEvent = localEvent;
          _dispatchAttempts = attempts;
          _offerEmergencyNumber = _primaryContact == null ||
              attempts.any(
                (attempt) =>
                    attempt.channel == 'call' && attempt.status == 'failed',
              );
        });
      }
      _startDispatchPolling();
      _showEmergencyNumberPromptIfNeeded();
      if (!_session.matches(ownerUserId, sessionAtStart.generation)) return;
      await _syncLocalEvent(localEvent, attempts);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _syncError == null
                  ? '本地 SOS 已执行并同步至云端'
                  : '本地 SOS 已执行，云端等待网络恢复后同步',
            ),
            backgroundColor: AppColors.emergency,
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('SOS 执行失败：${_sosFailureMessage(error)}')),
      );
    } finally {
      if (mounted) setState(() => _submittingSos = false);
    }
  }

  Future<({DateTime triggeredAt, SosLocationResult location})> _resolvePreview({
    DateTime? triggeredAt,
    OfflineSessionSnapshot? sessionAtStart,
  }) async {
    final effectiveTriggeredAt = triggeredAt ?? DateTime.now();
    final location = await _deviceService.resolveLocation();
    final message = SosPreviewBuilder.build(
      displayName: _displayName,
      triggeredAt: effectiveTriggeredAt,
      location: location,
    );
    if (mounted &&
        (sessionAtStart == null ||
            (sessionAtStart.ownerUserId != null &&
                _session.matches(
                  sessionAtStart.ownerUserId!,
                  sessionAtStart.generation,
                )))) {
      setState(() {
        _previewTriggeredAt = effectiveTriggeredAt;
        _previewLocation = location;
        _previewMessage = message;
      });
    }
    return (triggeredAt: effectiveTriggeredAt, location: location);
  }

  Future<void> _preparePreviewOnly() async {
    if (_preparingPreview || _submittingSos) return;
    final sessionAtStart = _session;
    if (sessionAtStart.ownerUserId == null) return;
    setState(() => _preparingPreview = true);
    try {
      await _resolvePreview(sessionAtStart: sessionAtStart);
    } finally {
      if (mounted) setState(() => _preparingPreview = false);
    }
  }

  Future<void> _restoreLocalSosState() async {
    final sessionAtStart = _session;
    final ownerUserId = sessionAtStart.ownerUserId;
    if (ownerUserId == null) return;
    try {
      final events = await _deviceService.getLocalSosEvents(
        ownerUserId: ownerUserId,
        pendingOnly: true,
      );
      if (events.isEmpty) return;
      var latest = events.first;
      if (latest.executionState == SosExecutionState.dispatching) {
        latest = latest.copyWith(executionState: SosExecutionState.unknown);
        await _deviceService.saveLocalSosEvent(latest);
      }
      final attempts = await _deviceService.getDispatchSnapshot(
        ownerUserId,
        latest.clientEventId,
      );
      if (!mounted ||
          !_session.matches(ownerUserId, sessionAtStart.generation)) {
        return;
      }
      setState(() {
        _localEvent = latest;
        _dispatchEventId = latest.clientEventId;
        _dispatchAttempts = attempts;
        _offerEmergencyNumber = attempts.isEmpty ||
            attempts.any(
              (attempt) =>
                  attempt.channel == 'call' && attempt.status == 'failed',
            );
        if (latest.executionState == SosExecutionState.unknown) {
          _syncError = '上次通信执行结果未知，不会自动重新发送；如仍需帮助请重新发起 SOS';
        }
      });
      if (!_allDispatchAttemptsTerminal) _startDispatchPolling();
      _showEmergencyNumberPromptIfNeeded();
      await _syncPendingLocalEvents();
    } catch (_) {
      // Web/不支持原生通道时不恢复本地 SOS。
    }
  }

  Future<void> _syncLocalEvent(
    LocalSosEventModel event,
    List<EmergencyDispatchAttemptModel> attempts,
  ) async {
    if (mounted) {
      setState(() {
        _syncingCloud = true;
        _syncError = null;
      });
    }
    try {
      await _uploadLocalEvent(event, attempts);
    } catch (error) {
      final message = _messageFor(error);
      await _deviceService.saveLocalSosEvent(event.copyWith(syncError: message));
      if (mounted) setState(() => _syncError = message);
    } finally {
      if (mounted) setState(() => _syncingCloud = false);
    }
  }

  Future<void> _uploadLocalEvent(
    LocalSosEventModel event,
    List<EmergencyDispatchAttemptModel> attempts,
  ) async {
    final sessionAtStart = _session;
    if (!_session.matches(
      event.ownerUserId,
      sessionAtStart.generation,
    )) {
      throw const ApiException('SOS 所属账号已切换，已停止同步');
    }
    final created = await _service.createSosEvent(
      clientEventId: event.clientEventId,
      triggeredAt: event.triggeredAt,
      latitude: event.latitude,
      longitude: event.longitude,
      accuracyMeters: event.accuracyMeters,
      locationSource: event.locationSource,
      message: event.message,
    );
    if (!created.success || created.data == null) {
      throw ApiException(created.message);
    }
    var cloudEvent = created.data!;
    if (attempts.isNotEmpty) {
      final updated = await _service.updateDispatchResults(
        event.clientEventId,
        attempts,
      );
      if (!updated.success || updated.data == null) {
        throw ApiException(updated.message);
      }
      cloudEvent = updated.data!;
    }
    if (!_session.matches(event.ownerUserId, sessionAtStart.generation)) {
      throw const ApiException('SOS 所属账号已切换，已停止同步');
    }
    await _deviceService.markLocalSosEventSynced(
      event.ownerUserId,
      event.clientEventId,
    );
    final latestAttempts = await _deviceService.getDispatchSnapshot(
      event.ownerUserId,
      event.clientEventId,
    );
    if (_attemptFingerprint(latestAttempts) != _attemptFingerprint(attempts)) {
      await _deviceService.saveLocalSosEvent(event);
    }
    if (mounted) {
      setState(() {
        _lastEvent = cloudEvent;
        _syncError = null;
      });
    }
  }

  String _attemptFingerprint(List<EmergencyDispatchAttemptModel> attempts) {
    return attempts
        .map(
          (attempt) =>
              '${attempt.attemptId}|${attempt.status}|${attempt.errorCode ?? ''}',
        )
        .join(';');
  }

  Future<void> _syncPendingLocalEvents() async {
    if (_syncingCloud) return;
    final sessionAtStart = _session;
    final ownerUserId = sessionAtStart.ownerUserId;
    if (ownerUserId == null) return;
    _syncingCloud = true;
    if (mounted) setState(() {});
    try {
      final pending = await _deviceService.getLocalSosEvents(
        ownerUserId: ownerUserId,
        pendingOnly: true,
      );
      for (final event in pending) {
        if (!_session.matches(ownerUserId, sessionAtStart.generation)) return;
        final attempts = await _deviceService.getDispatchSnapshot(
          ownerUserId,
          event.clientEventId,
        );
        await _uploadLocalEvent(event, attempts);
      }
      if (mounted) setState(() => _syncError = null);
    } catch (error) {
      if (mounted) setState(() => _syncError = _messageFor(error));
    } finally {
      _syncingCloud = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _confirmCallEmergencyNumber() async {
    final ownerUserId = _session.ownerUserId;
    if (ownerUserId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('拨打 120'),
        content: const Text('确定要拨打公共急救电话 120 吗？该电话绝不会自动触发。'),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.emergency,
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('拨打 120'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _session.ownerUserId != ownerUserId) {
      return;
    }
    final clientEventId =
        _dispatchEventId ?? 'assist-${DateTime.now().microsecondsSinceEpoch}';
    try {
      final attempts = await _deviceService.callNumber(
        ownerUserId: ownerUserId,
        clientEventId: clientEventId,
        attemptId:
            '${clientEventId.length > 25 ? clientEventId.substring(clientEventId.length - 25) : clientEventId}-c-120',
        phone: '120',
        contactName: '公共急救 120',
      );
      if (!mounted || _session.ownerUserId != ownerUserId) return;
      setState(() => _dispatchAttempts = attempts);
      _startDispatchPolling();
      unawaited(_syncPendingLocalEvents());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法启动 120 拨号：${_sosFailureMessage(error)}')),
      );
    }
  }

  void _showEmergencyNumberPromptIfNeeded() {
    if (!_offerEmergencyNumber || _emergencyPromptShown || !mounted) return;
    _emergencyPromptShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_confirmCallEmergencyNumber());
    });
  }

  void _startDispatchPolling() {
    _dispatchPollTimer?.cancel();
    _dispatchPollCount = 0;
    _dispatchPollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _dispatchPollCount++;
      unawaited(_refreshDispatchSnapshot());
      if (_dispatchPollCount >= 120 || _allDispatchAttemptsTerminal) {
        _dispatchPollTimer?.cancel();
      }
    });
  }

  Future<void> _refreshDispatchSnapshot() async {
    final clientEventId = _dispatchEventId;
    final sessionAtStart = _session;
    final ownerUserId = sessionAtStart.ownerUserId;
    if (clientEventId == null || ownerUserId == null) return;
    try {
      final attempts = await _deviceService.getDispatchSnapshot(
        ownerUserId,
        clientEventId,
      );
      if (mounted && _session.matches(ownerUserId, sessionAtStart.generation)) {
        setState(() {
          _dispatchAttempts = attempts;
          _offerEmergencyNumber = _primaryContact == null ||
              attempts.any(
                (attempt) =>
                    attempt.channel == 'call' && attempt.status == 'failed',
              );
        });
      }
      _showEmergencyNumberPromptIfNeeded();
      unawaited(_syncPendingLocalEvents());
    } catch (_) {
      // 快照刷新失败不影响原生回执继续落盘。
    }
  }

  bool get _allDispatchAttemptsTerminal {
    return _attemptsAreTerminal(_dispatchAttempts);
  }

  void _dismissDispatchStatus() {
    _dispatchPollTimer?.cancel();
    setState(() {
      _localEvent = null;
      _dispatchEventId = null;
      _dispatchAttempts = const [];
      _syncError = null;
      _offerEmergencyNumber = false;
      _emergencyPromptShown = false;
    });
  }

  bool _attemptsAreTerminal(
    List<EmergencyDispatchAttemptModel> attempts,
  ) {
    if (attempts.isEmpty) return false;
    const terminal = {
      'delivered',
      'launched',
      'failed',
      'skipped_not_sms_capable',
    };
    return attempts.every((attempt) => terminal.contains(attempt.status));
  }

  String _messageFor(Object error) =>
      error is ApiException ? error.message : '网络异常，请稍后重试';

  String _sosFailureMessage(Object error) {
    if (kDebugMode) return _messageFor(error);
    return '请检查网络和设备权限后重试';
  }

  Future<void> _showSosHistory() async {
    final owner = _session.ownerUserId;
    final local = owner == null ? <LocalSosEventModel>[] : await _deviceService.getLocalSosEvents(ownerUserId: owner);
    if (!mounted) return;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SosHistorySheet(service: _service, localEvents: local),
    );
  }

  Future<void> _openContactManagement() async {
    await Navigator.of(context).pushNamed(RouteNames.emergencyContacts);
    if (mounted) await _loadContacts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 112),
          children: [
            // ========== SOS 主卡片（含脉冲呼救按钮） ==========
            _SosCard(
              submitting: _submittingSos,
              loadingReadiness: _loadingReadiness,
              requestingPermissions: _requestingPermissions,
              preparingPreview: _preparingPreview,
              readiness: _readiness,
              showDebugPreview: kDebugMode,
              onConfirm: _triggerSos,
              onRequestPermissions: _requestPermissions,
              onPreparePreview: _preparePreviewOnly,
            ),

            if (kDebugMode && _previewMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              _SosPreviewCard(
                contacts:
                    _contacts.where((contact) => contact.smsCapable).toList(),
                message: _previewMessage!,
                location: _previewLocation!,
                triggeredAt: _previewTriggeredAt!,
              ),
            ],

            if (_localEvent != null || _dispatchAttempts.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _SosDispatchStatusCard(
                attempts: _dispatchAttempts,
                syncingCloud: _syncingCloud,
                cloudSynced: _syncError == null &&
                    _lastEvent?.clientEventId == _dispatchEventId,
                syncError: _syncError,
                emphasizeEmergencyNumber: _offerEmergencyNumber,
                onRefresh: _refreshDispatchSnapshot,
                onCallEmergencyNumber: _confirmCallEmergencyNumber,
                onClose: _dismissDispatchStatus,
              ),
            ],

            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _showSosHistory,
                icon: const Icon(Icons.history_rounded),
                label: const Text('SOS 历史记录'),
              ),
            ),

            // ---- SOS 卡片与联系人区域之间的间距 ----
            const SizedBox(height: AppSpacing.xxl),

            // ---- "安全联系人" 区域标题 ----
            SectionTitle(
              title: '安全联系人',
              actionText: '管理',
              onActionTap: _openContactManagement,
            ),

            ..._buildContactCards(),
            const SizedBox(height: AppSpacing.xxl),
            SectionTitle(
              title: '附近医院',
              actionText:
                  _nearbyHospitals.isEmpty ? '获取附近医院' : '重新获取',
              onActionTap: _loadingHospitals ? null : _loadNearbyHospitals,
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                '由高德位置服务按当前位置检索，距离为直线距离；接诊能力请电话确认。',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ..._buildHospitalCards(),
          ],
        ),
      ),
      bottomNavigationBar:
          const IosBottomNavigation(currentRoute: RouteNames.emergency),
    );
  }

  List<Widget> _buildContactCards() {
    if (_loadingContacts) {
      return const [
        SizedBox(height: 140, child: LoadingView(message: '正在加载联系人')),
      ];
    }
    if (_contactsError != null) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: ErrorView(message: _contactsError!, onRetry: _loadContacts),
        ),
      ];
    }
    if (_contacts.isEmpty) {
      return const [
        _EmergencyInfoCard(
          icon: Icons.person_add_alt_1_rounded,
          title: '尚未设置紧急联系人',
          subtitle: '请先在联系人管理中添加可信联系人',
        ),
      ];
    }
    return _contacts
        .map(
          (contact) => _EmergencyInfoCard(
            icon: contact.priority == 1
                ? Icons.star_rounded
                : Icons.family_restroom_rounded,
            title: contact.name,
            subtitle: [
              if (contact.priority == 1) '主要联系人',
              if (contact.relationship?.isNotEmpty == true)
                contact.relationship!,
              _maskPhone(contact.phone),
            ].join(' · '),
          ),
        )
        .toList();
  }

  List<Widget> _buildHospitalCards() {
    if (_loadingHospitals) {
      return const [
        SizedBox(height: 120, child: LoadingView(message: '正在加载附近医院')),
      ];
    }
    if (_hospitalsError != null) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: ErrorView(
            message: _hospitalsError!,
            onRetry: _loadNearbyHospitals,
          ),
        ),
      ];
    }
    if (_nearbyHospitals.isEmpty) {
      return const [
        _EmergencyInfoCard(
          icon: Icons.local_hospital_rounded,
          title: '暂无附近医院信息',
          subtitle: '点击“获取附近医院”后按当前位置查询',
          softBlue: true,
        ),
      ];
    }
    return _nearbyHospitals
        .take(2)
        .map(
          (hospital) => _EmergencyInfoCard(
            icon: Icons.local_hospital_rounded,
            title: hospital.name,
            subtitle: [
              hospital.distance,
              hospital.address,
              if (hospital.phone?.trim().isNotEmpty == true) hospital.phone!,
            ].where((value) => value.trim().isNotEmpty).join(' · '),
            softBlue: true,
          ),
        )
        .toList();
  }

  String _maskPhone(String phone) {
    if (phone.length < 7) return phone;
    return '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}';
  }

  EmergencyContactModel? get _primaryContact {
    for (final contact in _contacts) {
      if (contact.priority == 1) return contact;
    }
    return null;
  }
}

// ==================== SOS 主卡片（脉冲动画 + 确认弹窗） ====================

/// SOS 呼救按钮卡片-点击弹出倒计时确认弹窗。
class _SosCard extends StatefulWidget {
  const _SosCard({
    required this.submitting,
    required this.loadingReadiness,
    required this.requestingPermissions,
    required this.preparingPreview,
    required this.readiness,
    required this.showDebugPreview,
    required this.onConfirm,
    required this.onRequestPermissions,
    required this.onPreparePreview,
  });

  final bool submitting;
  final bool loadingReadiness;
  final bool requestingPermissions;
  final bool preparingPreview;
  final SosDeviceReadiness? readiness;
  final bool showDebugPreview;
  final Future<void> Function() onConfirm;
  final Future<void> Function() onRequestPermissions;
  final Future<void> Function() onPreparePreview;

  @override
  State<_SosCard> createState() => _SosCardState();
}

class _SosCardState extends State<_SosCard>
    with SingleTickerProviderStateMixin {
  /// 脉冲动画控制器：周期缩放模拟心跳
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    // 心跳脉冲：1.0 → 1.04 → 1.0，周期约 2.2 秒，无限循环
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulseAnim = TweenSequence<double>([
      // 扩张阶段 (0% → 50%): 放大到 1.04
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.04), weight: 1),
      // 收缩阶段 (50% → 100%): 回到 1.0
      TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _pulseCtrl.repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ========== 确认弹窗（倒计时 10 秒自动确认） ==========

  void _showConfirmDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false, // 防止误触关闭
      builder: (ctx) => _ConfirmDialog(onConfirm: widget.onConfirm),
    );
  }

  // ========== 构建 ==========

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      color: const Color(0xCCFFFFFF),
      padding: const EdgeInsets.fromLTRB(28, 34, 28, 34),
      child: Column(
        children: [
          Text('紧急求救',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: AppColors.emergency,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  )),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '将尝试发送求助短信，并呼叫主要联系人。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.xxxl),

          // ========== SOS 脉冲按钮 ==========
          // Stack 三层：外圆+红圆脉冲缩放，SOS 文字固定居中
          PressableScale(
            scale: 0.94,
            onTap: widget.submitting ? null : _showConfirmDialog,
            child: SizedBox(
              width: 256,
              height: 256,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // ---- 底层：双圆叠加，共同参与脉冲缩放 ----
                  ExcludeSemantics(
                    child: AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (context, _) => Transform.scale(
                        scale: _pulseAnim.value,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 光晕外圆
                            Container(
                              width: 206,
                              height: 206,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.emergencySoft,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.emergency
                                        .withValues(alpha: 0.8),
                                    blurRadius: 30,
                                    offset: const Offset(0, 0),
                                  ),
                                ],
                              ),
                            ),
                            // 实心红圆
                            Container(
                              width: 206,
                              height: 206,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.emergency,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // ---- 上层：SOS 文字，不参与缩放 ----
                  widget.submitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'SOS',
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(color: Colors.white),
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          Text(
            widget.submitting ? '正在执行 SOS…' : '轻触按钮确认启动紧急求救。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          if (widget.loadingReadiness) ...[
            const SizedBox(height: AppSpacing.xs),
            const Text(
              '正在检查短信、电话和定位权限…',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
          ] else if (_missingPermissions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '尚未开启：${_missingPermissions.join('、')}。未授权时将按设备能力降级执行。',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.warning),
            ),
            TextButton(
              onPressed: widget.requestingPermissions
                  ? null
                  : widget.onRequestPermissions,
              child: Text(
                widget.requestingPermissions ? '正在申请权限…' : '开启所需权限',
              ),
            ),
          ],
          if (widget.showDebugPreview)
            TextButton.icon(
              onPressed:
                  widget.preparingPreview ? null : widget.onPreparePreview,
              icon: widget.preparingPreview
                  ? const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.preview_rounded, size: 18),
              label: const Text('开发调试预览（不发送）'),
            ),
        ],
      ),
    );
  }

  List<String> get _missingPermissions {
    final readiness = widget.readiness;
    if (readiness == null || !readiness.supported) return const [];
    return [
      if (readiness.smsPermission != SosPermissionState.granted) '短信权限',
      if (readiness.callPermission != SosPermissionState.granted) '电话权限',
      if (readiness.locationPermission != 'precise' &&
          readiness.locationPermission != 'approximate')
        '定位权限',
    ];
  }
}

// ==================== 确认弹窗（倒计时 10 秒） ====================

/// SOS 确认弹窗 — 10 秒倒计时后自动执行，可手动取消或立即执行。
class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({required this.onConfirm});

  /// 确认后的回调（触发 SOS）
  final Future<void> Function() onConfirm;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  int _countdown = 10;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 每秒递减，到 0 自动确认
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _countdown--);
      if (_countdown <= 0) {
        _timer?.cancel();
        Navigator.of(context).pop();
        unawaited(widget.onConfirm());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _cancel() {
    _timer?.cancel();
    Navigator.of(context).pop();
  }

  void _confirmNow() {
    _timer?.cancel();
    Navigator.of(context).pop();
    unawaited(widget.onConfirm());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl)),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: AppColors.emergency, size: 28),
          const SizedBox(width: AppSpacing.sm),
          const Text('紧急求助'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '确定要启动紧急求助吗？\n倒计时结束后，将按当前权限和设备状态尝试发送短信，并呼叫主要联系人。不会自动拨打120急救电话。',
          ),
          const SizedBox(height: AppSpacing.lg),
          // ---- 倒计时指示（最后 3 秒变红） ----
          Center(
            child: Text(
              '$_countdown 秒后自动执行',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: _countdown <= 3
                        ? AppColors.emergency
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: Row(
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(72, 48),
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  textStyle: const TextStyle(fontSize: 13),
                  foregroundColor: AppColors.textSecondary,
                ),
                onPressed: _cancel,
                child: const Text('取消'),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: AppColors.emergency,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: _confirmNow,
                  child: const Text('立即执行'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SosPreviewCard extends StatelessWidget {
  const _SosPreviewCard({
    required this.contacts,
    required this.message,
    required this.location,
    required this.triggeredAt,
  });

  final List<EmergencyContactModel> contacts;
  final String message;
  final SosLocationResult location;
  final DateTime triggeredAt;

  @override
  Widget build(BuildContext context) {
    final sourceLabel = switch (location.source) {
      'fresh' => '新鲜定位',
      'cached' => '15 分钟内缓存定位',
      _ => '无定位',
    };
    return GlassCard(
      color: AppColors.blueSurface,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('开发调试预览', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            '仅展示本次计划内容，未发送短信，也未拨打电话。',
            style: TextStyle(color: AppColors.emergency),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('时间：${DateFormat('yyyy-MM-dd HH:mm:ss').format(triggeredAt)}'),
          Text('定位来源：$sourceLabel'),
          Text(
            '短信联系人：${contacts.isEmpty ? '无' : contacts.map((item) => item.name).join('、')}',
          ),
          const SizedBox(height: AppSpacing.sm),
          SelectableText(message),
        ],
      ),
    );
  }
}

class _SosDispatchStatusCard extends StatelessWidget {
  const _SosDispatchStatusCard({
    required this.attempts,
    required this.syncingCloud,
    required this.cloudSynced,
    required this.syncError,
    required this.emphasizeEmergencyNumber,
    required this.onRefresh,
    required this.onCallEmergencyNumber,
    required this.onClose,
  });

  final List<EmergencyDispatchAttemptModel> attempts;
  final bool syncingCloud;
  final bool cloudSynced;
  final String? syncError;
  final bool emphasizeEmergencyNumber;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onCallEmergencyNumber;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      color: AppColors.emergencySoft,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sms_rounded, color: AppColors.emergency),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'SOS 执行状态',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: '刷新回执',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
                tooltip: '关闭执行状态',
              ),
            ],
          ),
          Text(
            _syncStateText(),
            style: TextStyle(
              color: cloudSynced ? AppColors.success : AppColors.warning,
            ),
          ),
          if (attempts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            ...attempts.map((attempt) => _DispatchAttemptRow(attempt: attempt)),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              '“电话已启动”只表示系统已打开通话或拨号界面，不表示对方已接听。',
              style: TextStyle(color: AppColors.textTertiary),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: onCallEmergencyNumber,
            icon: const Icon(Icons.local_hospital_rounded),
            label: Text(
              emphasizeEmergencyNumber ? '主要联系人不可用，确认拨打 120' : '仍需帮助？拨打 120',
            ),
          ),
        ],
      ),
    );
  }

  String _syncStateText() {
    if (syncingCloud) return '正在同步云端审计记录…';
    if (cloudSynced) return '本地执行结果已同步到云端。';
    if (syncError == null) return '本地通信已执行，云端待同步。';
    return kDebugMode
        ? '本地通信已执行，云端待同步：$syncError。'
        : '本地通信已执行，云端暂未同步，将在网络恢复后重试。';
  }
}

class _DispatchAttemptRow extends StatelessWidget {
  const _DispatchAttemptRow({required this.attempt});

  final EmergencyDispatchAttemptModel attempt;

  @override
  Widget build(BuildContext context) {
    final isSuccess = attempt.status == 'delivered' ||
        attempt.status == 'sent' ||
        attempt.status == 'launched';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isSuccess ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            size: 20,
            color: isSuccess ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '${attempt.contactName ?? '未知联系人'} · '
              '${attempt.channel == 'sms' ? '短信' : '电话'} · '
              '${_statusLabel(attempt)}',
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(EmergencyDispatchAttemptModel attempt) {
    if (attempt.status == 'launched' &&
        attempt.errorCode == 'dialer_fallback_permission_denied') {
      return '已打开系统拨号界面';
    }
    return switch (attempt.status) {
      'requested' => '已请求',
      'sent' => '已发送，等待投递回执',
      'delivered' => '已投递',
      'launched' => '电话已启动',
      'failed' => '失败（${_errorLabel(attempt.errorCode)}）',
      'skipped_not_sms_capable' => '已跳过：不可发短信',
      _ => kDebugMode ? attempt.status : '状态暂未确认',
    };
  }

  String _errorLabel(String? code) => switch (code) {
        'permission_denied' => '权限被拒绝',
        'no_default_sms_sim' => '未设置默认短信 SIM',
        'no_sim' => '未检测到可用 SIM',
        'no_service' => '无运营商服务',
        'radio_off' => '飞行模式或无线电关闭',
        'limit_exceeded' => '短信频率受限',
        'delivery_failed' => '运营商未确认投递',
        'invalid_phone' => '号码无效',
        'call_launch_failed' => '无法打开电话功能',
        null => '未知错误',
        _ => kDebugMode ? code : '设备暂未确认原因',
      };
}

// ==================== 联系人信息卡片 ====================

/// 紧急联系人 / 设施信息卡片 — 图标 + 名称 + 描述。
class _SosHistorySheet extends StatelessWidget {
  const _SosHistorySheet({required this.service, required this.localEvents});

  final EmergencyService service;
  final List<LocalSosEventModel> localEvents;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'SOS 历史记录',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: '关闭',
                  ),
                ],
              ),
              const Text(
                '这里只表示通信动作的执行结果，不代表联系人已响应或救援已经到达。',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: FutureBuilder<BaseResponse<List<EmergencyEventModel>>>(
                  future: service.getEvents(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const LoadingView(message: '正在加载 SOS 历史');
                    }
                    if (snapshot.hasError) {
                      return const Center(child: Text('SOS 历史加载失败，请稍后重试'));
                    }
                    final response = snapshot.data;
                    final localIds = localEvents.map((event) => event.clientEventId).toSet();
                    final events = (response?.data ?? const <EmergencyEventModel>[])
                        .where((event) => event.clientEventId == null || !localIds.contains(event.clientEventId))
                        .toList();
                    if (response?.success != true && localEvents.isEmpty) {
                      return Center(
                        child: Text(
                          kDebugMode
                              ? (response?.message ?? 'SOS 历史加载失败')
                              : 'SOS 历史加载失败，请稍后重试',
                        ),
                      );
                    }
                    if (events.isEmpty && localEvents.isEmpty) {
                      return const Center(child: Text('当前账号暂无 SOS 记录'));
                    }
                    return ListView.separated(
                      itemCount: localEvents.length + events.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        if (index < localEvents.length) {
                          final event = localEvents[index];
                          return GlassCard(child: ListTile(
                            title: Text(DateFormat('yyyy-MM-dd HH:mm').format(event.triggeredAt)),
                            subtitle: Text(event.syncPending ? (event.syncError == null ? '本地记录 · 待同步' : '本地记录 · 同步失败') : '本地记录 · 已同步'),
                            trailing: event.executionState == SosExecutionState.unknown ? const Text('结果未知', style: TextStyle(color: AppColors.warning)) : null,
                          ));
                        }
                        final event = events[index - localEvents.length];
                        final time = event.triggeredAt ?? event.createdAt;
                        return GlassCard(
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding:
                                const EdgeInsets.only(top: AppSpacing.sm),
                            title: Text(
                              DateFormat('yyyy-MM-dd HH:mm').format(time),
                            ),
                            subtitle: Text(_historyStatus(event.status)),
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '已投递短信联系人：${event.contactsNotified}',
                                ),
                              ),
                              if (event.latitude != null &&
                                  event.longitude != null)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '位置：${event.latitude!.toStringAsFixed(5)}, '
                                    '${event.longitude!.toStringAsFixed(5)}',
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _historyStatus(String? status) {
    return switch (status) {
      'dispatching' => '通信动作执行中',
      'completed' => '预定通信动作已执行完毕',
      'partial_failure' => '部分通信动作失败',
      'failed' => '通信动作失败',
      _ => '事件已记录',
    };
  }
}

class _EmergencyInfoCard extends StatelessWidget {
  const _EmergencyInfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.softBlue = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool softBlue;

  @override
  Widget build(BuildContext context) {
    // softBlue=false → 红色, softBlue=true → 蓝色
    final color = softBlue ? AppColors.chartBlue : AppColors.emergency;
    final background =
        softBlue ? AppColors.blueSurface : AppColors.emergencySoft;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GlassCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

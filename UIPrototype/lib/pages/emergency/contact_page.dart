import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_runtime_settings.dart';
import '../../app/design_tokens.dart';
import '../../models/emergency_contact_model.dart';
import '../../services/api_client.dart';
import '../../services/emergency_service.dart';
import '../../services/emergency_contact_offline_repository.dart';
import '../../services/offline_session_coordinator.dart';
import '../../utils/validator_util.dart';
import '../../widgets/common/empty_view.dart';
import '../../widgets/common/error_view.dart';
import '../../widgets/common/loading_view.dart';
import '../../widgets/glass_card.dart';

const double _fabBottomPadding = 8;
const double _listBottomClearance = 168;

class ContactPage extends StatefulWidget {
  const ContactPage({super.key, this.service});

  final EmergencyService? service;

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  // Service 负责远端持久化；页面只维护加载、保存和错误反馈状态。
  late final EmergencyService _service;
  late final EmergencyContactOfflineRepository _offline;
  StreamSubscription<List<EmergencyContactModel>>? _syncSubscription;
  List<EmergencyContactModel> _contacts = const [];
  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? EmergencyService();
    _offline = EmergencyContactOfflineRepository(remote: _service);
    _syncSubscription = _offline.changes.listen((contacts) {
      if (!mounted) return;
      setState(() => _contacts = contacts);
    });
    _load();
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  /// 从后端重新读取联系人，新增、编辑和删除成功后复用此方法刷新。
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final owner = OfflineSessionCoordinator.session.value.ownerUserId;
      if (owner != null) { final cached=await _offline.cached(owner); if(cached!=null&&mounted)setState((){_contacts=cached;_loading=false;}); }
      final response = owner == null ? await _service.getContacts() : await _offline.get(owner);
      if (!response.success || response.data == null) {
        throw ApiException(response.message);
      }
      if (mounted) {
        setState(() {
          _contacts = response.data!;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = _messageFor(error);
        });
      }
    }
  }

  /// 同一编辑器同时承担新增和修改，提交后由 Service 选择 POST 或 PUT。
  Future<void> _edit([EmergencyContactModel? contact]) async {
    final draft = await showDialog<EmergencyContactModel>(
      context: context,
      builder: (_) => _ContactEditor(
        contact: contact,
        defaultPrimary: contact?.priority == 1 || _contacts.isEmpty,
        existingContacts: _contacts,
      ),
    );
    if (!mounted || draft == null || _saving) return;
    setState(() => _saving = true);
    try {
      final owner=OfflineSessionCoordinator.session.value.ownerUserId;
      final response = owner == null ? (contact == null ? await _service.saveContact(draft) : await _service.updateContact(draft.copyWith(id: contact.id))) : await _offline.save(owner, contact == null ? draft : draft.copyWith(id: contact.id));
      if (!response.success || response.data == null) {
        throw ApiException(response.message);
      }
      final saved = response.data!;
      setState(
        () => _contacts = _applyContactIntent(
          previous: _contacts,
          original: contact,
          draft: draft,
          saved: saved,
        ),
      );
      try {
        final refreshedContacts = owner == null
            ? (await _service.getContacts()).data
            : await _offline.cached(owner);
        if (mounted && refreshedContacts != null) {
          setState(() => _contacts = refreshedContacts);
        }
      } catch (_) {
        // 保存已经成功；刷新失败时保留刚刚完成排斥重排的本地视图。
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(contact == null ? '联系人已添加' : '联系人已更新')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_messageFor(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<EmergencyContactModel> _applyContactIntent({
    required List<EmergencyContactModel> previous,
    required EmergencyContactModel? original,
    required EmergencyContactModel draft,
    required EmergencyContactModel saved,
  }) {
    final targetId = original?.id ?? saved.id;
    final contacts = previous
        .where((item) => item.id != targetId)
        .toList();
    final removePrimary =
        original?.priority == 1 && draft.priority != 1;
    if (draft.priority == 1) {
      contacts.insert(0, saved);
    } else if (removePrimary) {
      contacts.add(saved);
    } else {
      final oldIndex = previous.indexWhere((item) => item.id == targetId);
      contacts.insert(oldIndex < 0 ? contacts.length : oldIndex, saved);
    }
    return [
      for (var index = 0; index < contacts.length; index++)
        contacts[index].copyWith(priority: index + 1),
    ];
  }

  /// 用户确认后删除联系人，并重新加载服务端整理后的优先级顺序。
  Future<void> _delete(EmergencyContactModel contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除联系人'),
        content: Text('确定删除“${contact.name}”吗？'),
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
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.emergency,
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
    if (confirmed != true || _saving) return;
    setState(() => _saving = true);
    try {
      final owner=OfflineSessionCoordinator.session.value.ownerUserId;
      final response = owner == null ? await _service.deleteContact(contact.id) : await _offline.delete(owner, contact.id);
      if (!response.success) throw ApiException(response.message);
      setState(() => _contacts = _contacts.where((item) => item.id != contact.id).toList());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_messageFor(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _messageFor(Object error) =>
      error is ApiException ? error.message : '操作失败，请稍后重试';

  static String? _validatePhone(String? value) {
    return ValidatorUtil.phone(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('')),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: _fabBottomPadding),
        child: FloatingActionButton.extended(
          onPressed: _saving ? null : _edit,
          backgroundColor: AppColors.emergency,
          foregroundColor: Colors.white,
          elevation: 0,
          highlightElevation: 0,
          extendedPadding: const EdgeInsets.symmetric(horizontal: 30),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('添加联系人'),
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppGradients.page,
          ),
        ),
        child: _loading
            ? const LoadingView(message: '正在加载联系人')
            : _errorMessage != null
                ? ErrorView(message: _errorMessage!, onRetry: _load)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      22,
                      12,
                      22,
                      _listBottomClearance,
                    ),
                    children: [
                      Text(
                        '管理您的紧急联系人',
                        style:
                            Theme.of(context).textTheme.headlineLarge?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      // 说明联系人在当前 SOS 流程中的实际用途。
                      Text(
                        '确认启动 SOS 后，会尝试向可接收短信的联系人发送求助短信，并呼叫主要联系人。',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (_contacts.isEmpty)
                        EmptyView(
                          title: '还没有紧急联系人',
                          message: '添加后可在紧急求救页查看，并用于 SOS 联系流程。',
                          action: FilledButton.icon(
                            onPressed: _saving ? null : _edit,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('添加第一位联系人'),
                          ),
                        )
                      else
                        for (final contact in _contacts) ...[
                          _ContactCard(
                            contact: contact,
                            onEdit: _saving ? null : () => _edit(contact),
                            onDelete: _saving ? null : () => _delete(contact),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                    ],
                  ),
      ),
    );
  }
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

  @override
  Widget build(BuildContext context) {
    final useStackedLayout = AppRuntimeSettings.instance.largeTouchTarget ||
        MediaQuery.textScalerOf(context).scale(1) > 1.15;
    final contactIdentity = Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.emergencySoft,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: const Icon(
            Icons.contact_phone_rounded,
            color: AppColors.emergency,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xxs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    contact.name,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (contact.priority == 1) const _PrimaryBadge(),
                  if (contact.syncState != ContactSyncState.synced)
                    Text(contact.syncState == ContactSyncState.failed ? '同步失败' : '待同步',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: contact.syncState == ContactSyncState.failed ? AppColors.emergency : AppColors.warning)),
                ],
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '${contact.relationship?.isNotEmpty == true ? '${contact.relationship} · ' : ''}${contact.phone}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
    final contactActions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
    );
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: useStackedLayout
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                contactIdentity,
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: contactActions,
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: contactIdentity),
                const SizedBox(width: AppSpacing.xs),
                contactActions,
              ],
            ),
    );
  }
}

class _PrimaryBadge extends StatelessWidget {
  const _PrimaryBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.emergencySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '主要联系人',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.emergency,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _ContactEditor extends StatefulWidget {
  const _ContactEditor({
    this.contact,
    required this.defaultPrimary,
    required this.existingContacts,
  });

  final EmergencyContactModel? contact;
  final bool defaultPrimary;
  final List<EmergencyContactModel> existingContacts;

  @override
  State<_ContactEditor> createState() => _ContactEditorState();
}

class _ContactEditorState extends State<_ContactEditor> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _relationship;
  late bool _primary;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.contact?.name ?? '');
    _phone = TextEditingController(text: widget.contact?.phone ?? '');
    _relationship =
        TextEditingController(text: widget.contact?.relationship ?? '');
    _primary = widget.defaultPrimary;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _relationship.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.pop(
      context,
      EmergencyContactModel(
        id: widget.contact?.id ?? 0,
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        relationship: _relationship.text.trim().isEmpty
            ? null
            : _relationship.text.trim(),
        // 请求字段只表达主要标记意图，实际联系人顺序由服务端统一生成。
        priority: _primary ? 1 : 0,
      ),
    );
  }

  String? _validatePhone(String? value) {
    final formatError = _ContactPageState._validatePhone(value);
    if (formatError != null) return formatError;
    final phone = value!.trim();
    final duplicate = widget.existingContacts.any(
      (contact) =>
          contact.id != widget.contact?.id && contact.phone.trim() == phone,
    );
    return duplicate ? '该手机号已存在，请勿重复添加' : null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.contact == null ? '添加联系人' : '编辑联系人'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                maxLength: 64,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: '姓名 *'),
                validator: (value) {
                  final name = value?.trim() ?? '';
                  if (name.isEmpty) return '请输入联系人姓名';
                  if (name.length > 64) return '联系人姓名不能超过 64 个字符';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _relationship,
                maxLength: 64,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: '关系'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: '大陆手机号 *'),
                validator: _validatePhone,
              ),
              const SizedBox(height: AppSpacing.sm),
              Material(
                color: AppColors.emergencySoft.withValues(alpha: 0.42),
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  side: BorderSide(
                    color: AppColors.emergency.withValues(alpha: 0.12),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xxs,
                  ),
                  value: _primary,
                  title: const Text('设为主要联系人'),
                  subtitle: const Text('SOS 启动后优先呼叫此联系人'),
                  onChanged: (value) => setState(() => _primary = value),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('保存'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

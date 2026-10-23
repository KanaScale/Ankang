import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../models/agent_action.dart';
import '../../models/family_models.dart';
import '../../services/family_service.dart';
import '../../widgets/agent_action_card.dart';
import '../../widgets/glass_card.dart';

class FamilyAgentPage extends StatefulWidget {
  const FamilyAgentPage({
    super.key,
    required this.patient,
    this.service,
  });

  final BoundPatientModel patient;
  final FamilyService? service;

  @override
  State<FamilyAgentPage> createState() => _FamilyAgentPageState();
}

class _FamilyAgentPageState extends State<FamilyAgentPage>
    with WidgetsBindingObserver {
  final _messageController = TextEditingController();
  final _messageFocusNode = FocusNode();
  final _messageScrollController = ScrollController();
  final _messageComposerKey = GlobalKey();
  late final FamilyService _service;
  int? _sessionId;
  var _sending = false;
  double _messageComposerHeight = 68;
  final _messages = <_CareChatMessage>[
    const _CareChatMessage(
      text: '照护者视角：我会基于已授权的健康数据回答家属问题。',
      fromAgent: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _messageFocusNode.addListener(_handleComposerFocusChanged);
    _messageController.addListener(_measureMessageComposer);
    _service = widget.service ?? FamilyService();
    _measureMessageComposer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageFocusNode.removeListener(_handleComposerFocusChanged);
    _messageController.removeListener(_measureMessageComposer);
    _messageFocusNode.dispose();
    _messageScrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _handleComposerFocusChanged() {
    if (_messageFocusNode.hasFocus) {
      _scrollToLatest();
    }
  }

  @override
  void didChangeMetrics() {
    _measureMessageComposer();
    _scrollToLatest();
  }

  void _measureMessageComposer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderBox =
          _messageComposerKey.currentContext?.findRenderObject() as RenderBox?;
      final height = renderBox?.size.height;
      if (height == null || (height - _messageComposerHeight).abs() < 0.5) {
        return;
      }
      setState(() => _messageComposerHeight = height);
      _scrollToLatest();
    });
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_messageScrollController.hasClients) return;
      _messageScrollController.animateTo(
        _messageScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _send([String? preset]) async {
    if (_sending) return;
    final text = (preset ?? _messageController.text).trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_CareChatMessage(text: text, fromAgent: false));
      _messageController.clear();
      _sending = true;
    });
    _scrollToLatest();
    try {
      final response = await _service.familyAgentChat(
        patientId: widget.patient.patientUserId,
        message: text,
        sessionId: _sessionId,
      );
      if (!mounted) return;
      final reply = response.data;
      setState(() {
        if (response.success && reply != null && reply.sessionId != 0) {
          _sessionId = reply.sessionId;
        }
        _messages.add(
          _CareChatMessage(
            text: response.success
                ? (reply?.answer.trim().isNotEmpty == true
                    ? reply!.answer
                    : '照护者视角：暂时没有可用回答。')
                : (response.message.isEmpty ? '照护咨询暂时不可用' : response.message),
            fromAgent: true,
            action: reply?.pendingAction,
          ),
        );
      });
      _scrollToLatest();
    } catch (error) {
      if (mounted) {
        setState(() {
          _messages
              .add(_CareChatMessage(text: error.toString(), fromAgent: true));
        });
        _scrollToLatest();
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('${widget.patient.patientName} · Agent')),
      body: SafeArea(
        child: Column(
          children: [
            ClipRect(
              child: AnimatedAlign(
                key: const ValueKey('family_agent_prompt_header'),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topCenter,
                heightFactor: keyboardVisible ? 0 : 1,
                child: IgnorePointer(
                  ignoring: keyboardVisible,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOut,
                    opacity: keyboardVisible ? 0 : 1,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                      child: _PromptRow(onSelected: _send),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ListView.builder(
                      key: const ValueKey('family_agent_message_list'),
                      controller: _messageScrollController,
                      padding: EdgeInsets.fromLTRB(
                        18,
                        18,
                        18,
                        (keyboardVisible ? AppSpacing.sm : AppSpacing.lg) +
                            _messageComposerHeight,
                      ),
                      itemCount: _messages.length + (_sending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length) {
                          return const _ChatBubble(
                            message: _CareChatMessage(
                              text: '正在整理照护建议...',
                              fromAgent: true,
                            ),
                          );
                        }
                        return _ChatBubble(
                          message: _messages[index],
                          onActionSubmit: _confirmAction,
                        );
                      },
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: keyboardVisible ? AppSpacing.sm : AppSpacing.lg,
                    child: KeyedSubtree(
                      key: const ValueKey('family_agent_message_composer'),
                      child: _Composer(
                        key: _messageComposerKey,
                        controller: _messageController,
                        focusNode: _messageFocusNode,
                        sending: _sending,
                        onSend: _send,
                      ),
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

  Future<AgentActionModel?> _confirmAction(
    AgentActionModel action,
    bool confirmed,
  ) async {
    try {
      final response = await _service.confirmAgentAction(
        actionId: action.actionId,
        confirmed: confirmed,
      );
      if (!mounted) return null;
      if (!response.success || response.data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                response.message.isEmpty ? '操作失败，请稍后再试' : response.message),
          ),
        );
        return AgentActionModel(
          actionId: action.actionId,
          actionType: action.actionType,
          title: action.title,
          description: action.description,
          status: 'FAILED',
          payload: action.payload,
          resultMessage:
              response.message.isEmpty ? '操作失败，请稍后再试' : response.message,
        );
      }
      return response.data;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
      return AgentActionModel(
        actionId: action.actionId,
        actionType: action.actionType,
        title: action.title,
        description: action.description,
        status: 'FAILED',
        payload: action.payload,
        resultMessage: '操作失败，请稍后再试',
      );
    }
  }
}

class _PromptRow extends StatelessWidget {
  const _PromptRow({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _PromptChip(text: '他最近血压怎么样？', onSelected: onSelected),
          _PromptChip(text: '今天有没有按时吃药？', onSelected: onSelected),
          _PromptChip(text: '最近一周心率有没有异常？', onSelected: onSelected),
          _PromptChip(text: '血糖趋势需要注意什么？', onSelected: onSelected),
        ],
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({
    required this.text,
    required this.onSelected,
  });

  final String text;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: ActionChip(
        onPressed: () => onSelected(text),
        avatar: const Icon(Icons.add_rounded, size: 18),
        label: Text(text),
        backgroundColor: AppColors.surfaceGlass,
        side: const BorderSide(color: AppColors.border),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    this.onActionSubmit,
  });

  final _CareChatMessage message;
  final AgentActionSubmit? onActionSubmit;

  @override
  Widget build(BuildContext context) {
    final alignment =
        message.fromAgent ? Alignment.centerLeft : Alignment.centerRight;
    final background =
        message.fromAgent ? AppColors.surfaceGlass : AppColors.primary;
    final foreground = message.fromAgent ? AppColors.textPrimary : Colors.white;
    return Align(
      alignment: alignment,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border:
              message.fromAgent ? Border.all(color: AppColors.border) : null,
          boxShadow: AppShadows.subtle,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: foreground,
                  ),
            ),
            if (message.action != null && onActionSubmit != null)
              AgentActionCard(
                action: message.action!,
                onSubmit: onActionSubmit!,
              ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 10, 10, 10),
      borderRadius: AppRadius.xxl,
      blur: 22,
      opacity: 0.78,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('family_agent_message_input'),
              controller: controller,
              focusNode: focusNode,
              enabled: !sending,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: onSend,
              decoration: const InputDecoration(
                hintText: '输入照护问题',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton.filled(
            onPressed: sending ? null : () => onSend(controller.text),
            icon: const Icon(Icons.arrow_upward_rounded),
          ),
        ],
      ),
    );
  }
}

class _CareChatMessage {
  const _CareChatMessage({
    required this.text,
    required this.fromAgent,
    this.action,
  });

  final String text;
  final bool fromAgent;
  final AgentActionModel? action;
}

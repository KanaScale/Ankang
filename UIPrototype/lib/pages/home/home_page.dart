import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_runtime_settings.dart';
import '../../app/design_tokens.dart';
import '../../models/agent_action.dart';
import '../../models/agent_chat_model.dart';
import '../../routes/route_names.dart';
import '../../services/agent_service.dart';
import '../../services/care_mode_service.dart';
import '../../widgets/avatar_view.dart';
import '../../widgets/agent_action_card.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/ios_bottom_navigation.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    this.initialPrompt,
    this.skipCareModeEntry = false,
  });

  final String? initialPrompt;
  final bool skipCareModeEntry;

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      extendBody: !keyboardVisible,
      resizeToAvoidBottomInset: true,
      bottomNavigationBar: keyboardVisible
          ? null
          : const IosBottomNavigation(currentRoute: RouteNames.home),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppGradients.page,
          ),
        ),
        child: _AgentConversationBody(
          initialPrompt: initialPrompt,
          skipCareModeEntry: skipCareModeEntry,
          keyboardVisible: keyboardVisible,
        ),
      ),
    );
  }
}

class _AgentConversationBody extends StatefulWidget {
  const _AgentConversationBody({
    required this.keyboardVisible,
    this.initialPrompt,
    this.skipCareModeEntry = false,
  });

  final bool keyboardVisible;
  final String? initialPrompt;
  final bool skipCareModeEntry;

  @override
  State<_AgentConversationBody> createState() => _AgentConversationBodyState();
}

class _AgentConversationBodyState extends State<_AgentConversationBody>
    with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _messageScrollController = ScrollController();
  final GlobalKey _messageComposerKey = GlobalKey();
  final AgentService _agentService = AgentService();
  int? _sessionId;
  bool _sending = false;
  bool _loadingMessages = false;
  bool _modePromptShown = false;
  double _messageComposerHeight = 68;
  List<AgentSessionModel> _sessions = const [];
  List<_ChatMessage> _messages = _welcomeMessages();

  static List<_ChatMessage> _welcomeMessages() => [
        const _ChatMessage(
          text: '早上。我可以帮您查看健康数据、理解体检报告、安排用药提醒，也可以回答日常健康问题。',
          fromAgent: true,
        ),
      ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _messageFocusNode.addListener(_handleComposerFocusChanged);
    _messageController.addListener(_measureMessageComposer);
    _initialize();
    _measureMessageComposer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_applyCareModeEntry());
    });
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

  Future<void> _initialize() async {
    final prompt = widget.initialPrompt?.trim();
    await _loadSessions(selectMostRecent: prompt == null || prompt.isEmpty);
    if (mounted && prompt != null && prompt.isNotEmpty) {
      await _sendMessage(prompt);
    }
  }

  Future<void> _applyCareModeEntry() async {
    if (widget.skipCareModeEntry) return;
    if (!mounted || _modePromptShown) return;
    _modePromptShown = true;

    if (CareModeService.selectionKnown.value) {
      if (CareModeService.isCaregiver) {
        Navigator.of(context).pushReplacementNamed(RouteNames.family);
      }
      return;
    }

    final selected = await showDialog<CareMode>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CareModeDialog(),
    );
    if (selected == null) return;
    await CareModeService.selectMode(selected);
    if (!mounted) return;
    if (selected == CareMode.caregiver) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        RouteNames.family,
        (route) => false,
      );
    }
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

  void _measureMessageComposer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
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
      if (!mounted || !_messageScrollController.hasClients) {
        return;
      }
      _messageScrollController.animateTo(
        _messageScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _sendMessage([String? preset]) async {
    if (_sending) {
      return;
    }
    final text = (preset ?? _messageController.text).trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(text: text, fromAgent: false));
      _messageController.clear();
      _sending = true;
    });
    _scrollToLatest();

    try {
      final response = await _agentService.chat(
        message: text,
        sessionId: _sessionId,
      );
      final reply = response.data;
      final answer = response.success
          ? reply?.answer
          : response.message.isEmpty
              ? '智能问答暂时不可用，请稍后再试。'
              : response.message;
      if (!mounted) {
        return;
      }
      setState(() {
        if (response.success && reply != null && reply.sessionId != 0) {
          _sessionId = reply.sessionId;
        }
        _messages.add(
          _ChatMessage(
            text: answer?.trim().isNotEmpty == true
                ? answer!
                : '智能问答暂时不可用，请稍后再试。',
            fromAgent: true,
            citations: reply?.citations ?? const [],
            suggestions: reply?.suggestions ?? const [],
            action: reply?.pendingAction,
          ),
        );
      });
      _scrollToLatest();
      await _loadSessions(selectMostRecent: false);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(
          const _ChatMessage(
            text: '智能问答暂时不可用，请稍后再试。若出现紧急症状，请优先使用底部 SOS。',
            fromAgent: true,
          ),
        );
      });
      _scrollToLatest();
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _loadSessions({bool selectMostRecent = true}) async {
    try {
      final response = await _agentService.getSessions();
      if (!mounted || !response.success) {
        return;
      }
      final sessions = response.data ?? const <AgentSessionModel>[];
      setState(() => _sessions = sessions);
      if (selectMostRecent && sessions.isNotEmpty) {
        await _openSession(sessions.first.id);
      }
    } catch (_) {
      // 首页聊天仍可使用；历史会话加载失败时不阻断问答。
    }
  }

  Future<void> _openSession(int sessionId) async {
    if (_loadingMessages) {
      return;
    }
    setState(() {
      _loadingMessages = true;
      _sessionId = sessionId;
    });
    try {
      final response = await _agentService.getSessionMessages(sessionId);
      if (!mounted) {
        return;
      }
      if (response.success) {
        final loaded = (response.data ?? const <AgentMessageModel>[])
            .map(
              (item) => _ChatMessage(
                text: item.content,
                fromAgent: item.fromAgent,
              ),
            )
            .toList();
        setState(() {
          _messages = loaded.isEmpty ? _welcomeMessages() : loaded;
        });
        _scrollToLatest();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _messages = _welcomeMessages();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loadingMessages = false);
      }
    }
  }

  void _newConversation() {
    setState(() {
      _sessionId = null;
      _messages = _welcomeMessages();
    });
  }

  Future<void> _deleteSession(int sessionId) async {
    try {
      await _agentService.deleteSession(sessionId);
      if (!mounted) {
        return;
      }
      if (_sessionId == sessionId) {
        _newConversation();
      }
      await _loadSessions(selectMostRecent: false);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('删除会话失败，请稍后再试')),
      );
    }
  }

  Future<void> _showSessionSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _SessionSheet(
        sessions: _sessions,
        currentSessionId: _sessionId,
        onSelected: (id) {
          Navigator.of(context).pop();
          _openSession(id);
        },
        onDeleted: _deleteSession,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = widget.keyboardVisible;
    return AnimatedBuilder(
      animation: AppRuntimeSettings.instance,
      builder: (context, _) {
        final settings = AppRuntimeSettings.instance;
        final simpleMode = settings.simpleMode;
        final visibleMessages =
            _messages.length > settings.simpleChatHistoryLimit
                ? _messages
                    .sublist(_messages.length - settings.simpleChatHistoryLimit)
                : _messages;

        return SafeArea(
          bottom: false,
          child: Column(
            children: [
              ClipRect(
                child: AnimatedAlign(
                  key: const ValueKey('agent_chat_header'),
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
                        padding: EdgeInsets.fromLTRB(
                            22, simpleMode ? 12 : 18, 22, 0),
                        child: FadeSlideIn(
                          child: Column(
                            children: [
                              _ConversationHeader(
                                sessionTitle: _currentSessionTitle(),
                                simpleMode: simpleMode,
                                onHistory: _showSessionSheet,
                                onNew: _newConversation,
                              ),
                              SizedBox(
                                height:
                                    simpleMode ? AppSpacing.sm : AppSpacing.md,
                              ),
                              _PromptRow(
                                simpleMode: simpleMode,
                                onSelected: _sendMessage,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOutCubic,
                height: keyboardVisible ? 0 : AppSpacing.sm,
              ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: FadeSlideIn(
                        delay: const Duration(milliseconds: 80),
                        child: ListView.builder(
                          key: const ValueKey('agent_message_list'),
                          controller: _messageScrollController,
                          padding: EdgeInsets.fromLTRB(
                            22,
                            simpleMode ? 4 : 8,
                            22,
                            (keyboardVisible
                                    ? AppSpacing.sm
                                    : simpleMode
                                        ? 92
                                        : 104) +
                                _messageComposerHeight,
                          ),
                          itemCount: _loadingMessages
                              ? 1
                              : visibleMessages.length + (_sending ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (_loadingMessages) {
                              return _ChatBubble(
                                simpleMode: simpleMode,
                                onActionSubmit: _confirmAction,
                                message: const _ChatMessage(
                                  text: '正在加载历史消息...',
                                  fromAgent: true,
                                ),
                              );
                            }
                            if (index == visibleMessages.length) {
                              return _ChatBubble(
                                simpleMode: simpleMode,
                                onActionSubmit: _confirmAction,
                                message: const _ChatMessage(
                                  text: '正在整理建议...',
                                  fromAgent: true,
                                ),
                              );
                            }
                            return _ChatBubble(
                              message: visibleMessages[index],
                              simpleMode: simpleMode,
                              onActionSubmit: _confirmAction,
                            );
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      key: const ValueKey('agent_message_composer_padding'),
                      left: 22,
                      right: 22,
                      bottom: keyboardVisible
                          ? AppSpacing.sm
                          : simpleMode
                              ? 92
                              : 104,
                      child: FadeSlideIn(
                        delay: const Duration(milliseconds: 140),
                        child: KeyedSubtree(
                          key: const ValueKey('agent_message_composer'),
                          child: _MessageComposer(
                            key: _messageComposerKey,
                            controller: _messageController,
                            focusNode: _messageFocusNode,
                            onSend: _sendMessage,
                            sending: _sending,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _currentSessionTitle() {
    final sessionId = _sessionId;
    if (sessionId == null) {
      return '新对话';
    }
    for (final session in _sessions) {
      if (session.id == sessionId) {
        return session.title;
      }
    }
    return '当前会话';
  }

  Future<AgentActionModel?> _confirmAction(
    AgentActionModel action,
    bool confirmed,
  ) async {
    try {
      final response = await _agentService.confirmAction(
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

class _ConversationHeader extends StatelessWidget {
  const _ConversationHeader({
    required this.sessionTitle,
    required this.simpleMode,
    required this.onHistory,
    required this.onNew,
  });

  final String sessionTitle;
  final bool simpleMode;
  final VoidCallback onHistory;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AvatarView(size: simpleMode ? 48 : 58, icon: Icons.favorite_rounded),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                simpleMode ? '简洁问答' : '健康陪伴',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (!simpleMode) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '向安康助手咨询您的健康问题',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  sessionTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ],
          ),
        ),
        if (!simpleMode)
          IconButton(
            tooltip: '历史会话',
            onPressed: onHistory,
            icon: const Icon(Icons.history_rounded),
          ),
        IconButton(
          tooltip: '新对话',
          onPressed: onNew,
          icon: const Icon(Icons.add_comment_rounded),
        ),
      ],
    );
  }
}

class _CareModeDialog extends StatelessWidget {
  const _CareModeDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(
        Icons.switch_account_rounded,
        color: AppColors.primary,
        size: 32,
      ),
      title: const Text('选择使用模式', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CareModeChoice(
            title: '病人版',
            subtitle: '管理自己的健康数据、提醒和 SOS。',
            icon: Icons.monitor_heart_rounded,
            onTap: () => Navigator.of(context).pop(CareMode.patient),
          ),
          const SizedBox(height: AppSpacing.md),
          _CareModeChoice(
            title: '家属版',
            subtitle: '绑定病人后查看授权数据并咨询 Agent。',
            icon: Icons.family_restroom_rounded,
            onTap: () => Navigator.of(context).pop(CareMode.caregiver),
          ),
        ],
      ),
    );
  }
}

class _CareModeChoice extends StatelessWidget {
  const _CareModeChoice({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 30),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
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
      ),
    );
  }
}

class _PromptRow extends StatelessWidget {
  const _PromptRow({
    required this.simpleMode,
    required this.onSelected,
  });

  final bool simpleMode;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final prompts = simpleMode
        ? const ['今天重点做什么', '指标异常怎么办']
        : const ['解读今日血压', '设置服药提醒', '分析血糖变化', '体检报告怎么看'];
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: prompts
            .map((text) => _PromptChip(text: text, onSelected: onSelected))
            .toList(),
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
        label: Text(text),
        avatar: const Icon(Icons.add_rounded, size: 18),
        backgroundColor: AppColors.surfaceGlass,
        side: const BorderSide(color: AppColors.border),
        labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    this.onActionSubmit,
    required this.simpleMode,
  });

  final _ChatMessage message;
  final AgentActionSubmit? onActionSubmit;
  final bool simpleMode;

  @override
  Widget build(BuildContext context) {
    final alignment =
        message.fromAgent ? Alignment.centerLeft : Alignment.centerRight;
    final background =
        message.fromAgent ? AppColors.surfaceGlass : AppColors.primary;
    final foreground = message.fromAgent ? AppColors.textPrimary : Colors.white;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(AppRadius.xl),
      topRight: const Radius.circular(AppRadius.xl),
      bottomLeft:
          Radius.circular(message.fromAgent ? AppRadius.sm : AppRadius.xl),
      bottomRight:
          Radius.circular(message.fromAgent ? AppRadius.xl : AppRadius.sm),
    );

    return Align(
      alignment: alignment,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: radius,
          border: message.fromAgent
              ? Border.all(color: const Color(0xB3FFF7EF))
              : null,
          boxShadow: AppShadows.subtle,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              maxLines: simpleMode && message.fromAgent ? 6 : null,
              overflow: simpleMode && message.fromAgent
                  ? TextOverflow.ellipsis
                  : null,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: foreground,
                  ),
            ),
            if (!simpleMode && message.citations.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.54),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        '参考来源：${message.citations.map((item) => item.title).join('、')}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!simpleMode && message.suggestions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: message.suggestions
                    .map(
                      (item) => ActionChip(
                        onPressed: () => _handleSuggestionTap(context, item),
                        label: Text(
                          item,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        visualDensity: VisualDensity.compact,
                        avatar: Icon(
                          _suggestionIcon(item),
                          size: 16,
                        ),
                        backgroundColor: Colors.white.withValues(alpha: 0.76),
                        side: const BorderSide(color: AppColors.border),
                      ),
                    )
                    .toList(),
              ),
            ],
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

  void _handleSuggestionTap(BuildContext context, String suggestion) {
    final route = _routeForSuggestion(suggestion);
    if (route == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已收到：$suggestion')),
      );
      return;
    }
    Navigator.of(context).pushNamed(route);
  }

  String? _routeForSuggestion(String suggestion) {
    if (suggestion.contains('提醒') ||
        suggestion.contains('药品') ||
        suggestion.contains('剂量')) {
      return RouteNames.reminder;
    }
    if (suggestion.contains('报告')) {
      return RouteNames.reports;
    }
    if (suggestion.contains('健康') ||
        suggestion.contains('记录') ||
        suggestion.contains('趋势') ||
        suggestion.contains('血压') ||
        suggestion.contains('血糖') ||
        suggestion.contains('饮食')) {
      return RouteNames.health;
    }
    return null;
  }

  IconData _suggestionIcon(String suggestion) {
    if (suggestion.contains('提醒') || suggestion.contains('药')) {
      return Icons.alarm_rounded;
    }
    if (suggestion.contains('趋势')) {
      return Icons.show_chart_rounded;
    }
    if (suggestion.contains('记录')) {
      return Icons.add_chart_rounded;
    }
    return Icons.arrow_forward_rounded;
  }
}

class _SessionSheet extends StatelessWidget {
  const _SessionSheet({
    required this.sessions,
    required this.currentSessionId,
    required this.onSelected,
    required this.onDeleted,
  });

  final List<AgentSessionModel> sessions;
  final int? currentSessionId;
  final ValueChanged<int> onSelected;
  final ValueChanged<int> onDeleted;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          borderRadius: AppRadius.xl,
          opacity: 0.94,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: sessions.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text(
                      '暂无历史会话',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final selected = session.id == currentSessionId;
                      return ListTile(
                        selected: selected,
                        leading: Icon(
                          selected
                              ? Icons.chat_bubble_rounded
                              : Icons.chat_bubble_outline_rounded,
                        ),
                        title: Text(
                          session.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(_formatTime(session.updatedAt)),
                        onTap: () => onSelected(session.id),
                        trailing: IconButton(
                          tooltip: '删除会话',
                          onPressed: () => onDeleted(session.id),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) {
      return '';
    }
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${time.month}/${time.day} ${twoDigits(time.hour)}:${twoDigits(time.minute)}';
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.sending,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSend;
  final bool sending;

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
              key: const ValueKey('agent_message_input'),
              controller: controller,
              focusNode: focusNode,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              decoration: const InputDecoration(
                hintText: '输入想咨询的问题',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
              enabled: !sending,
              onSubmitted: onSend,
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

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.fromAgent,
    this.citations = const [],
    this.suggestions = const [],
    this.action,
  });

  final String text;
  final bool fromAgent;
  final List<AgentCitationModel> citations;
  final List<String> suggestions;
  final AgentActionModel? action;
}

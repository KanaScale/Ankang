package com.ankang.assistant.agent.service;

import com.ankang.assistant.agent.action.AgentActionRequest;
import com.ankang.assistant.agent.action.AgentActionService;
import com.ankang.assistant.agent.action.AgentActionType;
import com.ankang.assistant.agent.action.AgentActionVO;
import com.ankang.assistant.agent.action.AgentIntentParser;
import com.ankang.assistant.agent.dto.AgentChatDTO;
import com.ankang.assistant.agent.entity.AgentConversation;
import com.ankang.assistant.agent.entity.AgentMemory;
import com.ankang.assistant.agent.entity.AgentMessage;
import com.ankang.assistant.agent.gms.GmsMemoryClient;
import com.ankang.assistant.agent.gms.GmsMemoryItem;
import com.ankang.assistant.agent.llm.AgentChatTurn;
import com.ankang.assistant.agent.llm.AgentLlmClient;
import com.ankang.assistant.agent.mapper.AgentConversationMapper;
import com.ankang.assistant.agent.mapper.AgentMessageMapper;
import com.ankang.assistant.agent.tool.AgentToolExecutor;
import com.ankang.assistant.agent.tool.WebSearchResult;
import com.ankang.assistant.agent.vo.AgentCitationVO;
import com.ankang.assistant.agent.vo.AgentMessageVO;
import com.ankang.assistant.agent.vo.AgentReplyVO;
import com.ankang.assistant.agent.vo.AgentSessionVO;
import com.ankang.assistant.config.SecurityUtils;
import com.ankang.assistant.health.service.HealthService;
import com.ankang.assistant.health.vo.HealthRecordVO;
import com.ankang.assistant.health.vo.HealthSummaryVO;
import com.ankang.assistant.reminder.service.ReminderService;
import com.ankang.assistant.reminder.vo.ReminderVO;
import com.ankang.assistant.user.service.UserService;
import com.ankang.assistant.user.vo.HealthGoalVO;
import com.ankang.assistant.user.vo.HealthProfileVO;
import com.ankang.assistant.user.vo.UserProfileVO;
import com.ankang.assistant.user.vo.UserSettingVO;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.lang.reflect.Method;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Service
public class AgentService {

    private static final Logger log = LoggerFactory.getLogger(AgentService.class);
    private static final int RECENT_MESSAGE_LIMIT = 10;
    private static final int REMINDER_CONTEXT_LIMIT = 5;
    private static final int UPSTREAM_ERROR_SUMMARY_LIMIT = 500;
    private static final Pattern HTTP_STATUS_PATTERN =
            Pattern.compile("(?i)(?:http|status|code)[^0-9]{0,20}(\\d{3})");

    private final AgentConversationMapper conversationMapper;
    private final AgentMessageMapper messageMapper;
    private final AgentLlmClient llmClient;
    private final AgentToolExecutor toolExecutor;
    private final AgentToolDecisionService toolDecisionService;
    private final AgentPromptBuilder promptBuilder;
    private final AgentMemoryService memoryService;
    private final AgentSafetyService safetyService;
    private final AgentAnswerFormatter answerFormatter;
    private final UserService userService;
    private final HealthService healthService;
    private final ReminderService reminderService;
    private final AgentIntentParser intentParser;
    private final AgentActionService actionService;
    private final GmsMemoryClient gmsMemoryClient;

    @Autowired
    public AgentService(
            AgentConversationMapper conversationMapper,
            AgentMessageMapper messageMapper,
            AgentLlmClient llmClient,
            AgentToolExecutor toolExecutor,
            AgentToolDecisionService toolDecisionService,
            AgentPromptBuilder promptBuilder,
            AgentMemoryService memoryService,
            AgentSafetyService safetyService,
            AgentAnswerFormatter answerFormatter,
            UserService userService,
            HealthService healthService,
            ReminderService reminderService,
            AgentIntentParser intentParser,
            AgentActionService actionService,
            GmsMemoryClient gmsMemoryClient
    ) {
        this.conversationMapper = conversationMapper;
        this.messageMapper = messageMapper;
        this.llmClient = llmClient;
        this.toolExecutor = toolExecutor;
        this.toolDecisionService = toolDecisionService;
        this.promptBuilder = promptBuilder;
        this.memoryService = memoryService;
        this.safetyService = safetyService;
        this.answerFormatter = answerFormatter;
        this.userService = userService;
        this.healthService = healthService;
        this.reminderService = reminderService;
        this.intentParser = intentParser;
        this.actionService = actionService;
        this.gmsMemoryClient = gmsMemoryClient == null ? GmsMemoryClient.disabled() : gmsMemoryClient;
    }

    public AgentService(
            AgentConversationMapper conversationMapper,
            AgentMessageMapper messageMapper,
            AgentLlmClient llmClient,
            AgentToolExecutor toolExecutor,
            AgentToolDecisionService toolDecisionService,
            AgentPromptBuilder promptBuilder,
            AgentMemoryService memoryService,
            AgentSafetyService safetyService,
            AgentAnswerFormatter answerFormatter,
            UserService userService,
            HealthService healthService,
            ReminderService reminderService
    ) {
        this(
                conversationMapper,
                messageMapper,
                llmClient,
                toolExecutor,
                toolDecisionService,
                promptBuilder,
                memoryService,
                safetyService,
                answerFormatter,
                userService,
                healthService,
                reminderService,
                null,
                null,
                GmsMemoryClient.disabled()
        );
    }

    public AgentReplyVO chat(AgentChatDTO dto) {
        Long userId = SecurityUtils.currentUserId();
        return chatInternal(dto, userId, userId, "PATIENT");
    }

    public AgentReplyVO chatForCaregiver(Long caregiverUserId, Long patientUserId, AgentChatDTO dto) {
        return chatInternal(dto, caregiverUserId, patientUserId, "CAREGIVER");
    }

    private AgentReplyVO chatInternal(AgentChatDTO dto, Long actorUserId, Long targetUserId, String actorRole) {
        String userMessage = dto.message().trim();
        AgentConversation conversation = resolveConversation(actorUserId, targetUserId, actorRole,
                dto.sessionId(), userMessage);
        saveMessage(conversation.getId(), actorUserId, "user", userMessage);
        if (isPatientActor(actorRole)) {
            memoryService.rememberExplicitUserFact(actorUserId, userMessage);
            gmsMemoryClient.addMemoryAsync(
                    actorUserId,
                    "AnkangAgentChat",
                    userMessage,
                    "conversation",
                    List.of("agent_chat", "patient")
            );
        }

        Optional<AgentReplyVO> actionReply = handleActionIfNeeded(
                userMessage, actorUserId, targetUserId, actorRole, conversation);
        if (actionReply.isPresent()) {
            return actionReply.get();
        }

        List<AgentMemory> memories = isPatientActor(actorRole) ? memoryService.listMemories(actorUserId) : List.of();
        List<GmsMemoryItem> semanticMemories = gmsMemoryClient.searchMemories(targetUserId, userMessage);
        List<WebSearchResult> webSearchResults = searchIfNeeded(userMessage);
        String systemPrompt = promptBuilder.build(
                buildUserContext(targetUserId, actorRole),
                memories,
                semanticMemories,
                webSearchResults,
                safetyService.safetyInstruction(userMessage),
                actorRole
        );
        List<AgentChatTurn> turns = buildTurns(conversation.getId());

        String answer;
        try {
            answer = llmClient.chat(systemPrompt, turns);
        } catch (RuntimeException ex) {
            logLlmFailure(ex, actorUserId, targetUserId, actorRole, conversation.getId());
            answer = "智能问答服务暂时不可用。你可以稍后再试；如果出现胸痛、呼吸困难、意识异常等紧急情况，请立即使用 SOS 或联系急救。";
        }
        answer = answerFormatter.format(answer);
        answer = safetyService.enforceEmergencyNotice(userMessage, answer);
        if (!isPatientActor(actorRole) && !answer.startsWith("照护者视角")) {
            answer = "照护者视角：" + answer;
        }

        AgentMessage assistantMessage = saveMessage(conversation.getId(), actorUserId, "assistant", answer);
        touchConversation(conversation.getId());
        return new AgentReplyVO(
                conversation.getId(),
                assistantMessage.getId(),
                answer,
                buildCitations(webSearchResults),
                buildSuggestions(userMessage, actorRole),
                null
        );
    }

    private Optional<AgentReplyVO> handleActionIfNeeded(
            String userMessage,
            Long actorUserId,
            Long targetUserId,
            String actorRole,
            AgentConversation conversation
    ) {
        if (intentParser == null || actionService == null) {
            return Optional.empty();
        }
        Optional<AgentActionRequest> parsed = intentParser.parse(userMessage);
        if (parsed.isEmpty()) {
            return Optional.empty();
        }
        AgentActionRequest request = parsed.get();
        if (!isPatientActor(actorRole) && mutatesPatientData(request.actionType())) {
            return Optional.empty();
        }
        String answer;
        AgentActionVO pendingAction = null;
        List<String> suggestions = buildSuggestions(userMessage, actorRole);
        try {
            if (request.requiresConfirmation()) {
                pendingAction = actionService.createPendingAction(
                        actorUserId,
                        targetUserId,
                        actorRole,
                        conversation.getId(),
                        request
                );
                answer = pendingActionAnswer(request.actionType(), pendingAction.description());
            } else {
                AgentActionVO result = actionService.executeImmediate(
                        actorUserId,
                        targetUserId,
                        actorRole,
                        conversation.getId(),
                        request
                );
                answer = immediateActionAnswer(request.actionType(), result);
            }
        } catch (RuntimeException ex) {
            log.warn("Agent action preparation failed: actorUserId={}, targetUserId={}, actorRole={}, actionType={}, error={}",
                    actorUserId, targetUserId, actorRole, request.actionType(), ex.getMessage(), ex);
            answer = actionPreparationFailureAnswer(request.actionType(), ex);
        }
        answer = safetyService.enforceEmergencyNotice(userMessage, answer);
        if (!isPatientActor(actorRole) && !answer.startsWith("照护者视角")) {
            answer = "照护者视角：" + answer;
        }
        AgentMessage assistantMessage = saveMessage(conversation.getId(), actorUserId, "assistant", answer);
        touchConversation(conversation.getId());
        return Optional.of(new AgentReplyVO(
                conversation.getId(),
                assistantMessage.getId(),
                answer,
                List.of(),
                suggestions,
                pendingAction
        ));
    }

    private String pendingActionAnswer(AgentActionType actionType, String description) {
        return switch (actionType) {
            case RECORD_HEALTH_DATA -> "我识别到你想记录一条健康数据，请确认以下内容是否正确：" + safe(description);
            case CREATE_HEALTH_PLAN -> "我整理出一个健康计划，请确认是否按以下内容创建提醒：" + safe(description);
            case PREPARE_SOS_PLAN -> "我可以先生成 SOS 预案。确认后只会准备方案，不会自动报警、拨号或通知家属。";
            case NOTIFY_FAMILY_PREVIEW -> "我可以准备通知家属的消息预览。确认后不会直接发送，请你再次核对。";
            case SEARCH_NEARBY_HOSPITALS -> "我可以根据位置信息查询附近医院，请先确认。";
            case EVALUATE_HEALTH_RISK -> "我可以基于近期健康数据进行风险评估。";
        };
    }

    private String immediateActionAnswer(AgentActionType actionType, AgentActionVO result) {
        Map<String, Object> resultData = result.result() == null ? Map.of() : result.result();
        Object risk = resultData.get("risk");
        Object hospitals = resultData.get("nearbyHospitals");
        if (actionType == AgentActionType.EVALUATE_HEALTH_RISK && risk instanceof Map<?, ?> riskMap) {
            return "风险评估结果：" + safe(riskMap.get("summary"))
                    + "。风险评分 " + safe(riskMap.get("riskScore"))
                    + "，等级 " + safe(riskMap.get("riskLevel"))
                    + "。该结果不能替代医生诊断；如有明显不适，请及时就医。";
        }
        if (actionType == AgentActionType.SEARCH_NEARBY_HOSPITALS) {
            return result.resultMessage() == null ? "附近医院查询完成。" : result.resultMessage()
                    + (hospitals instanceof List<?> list && !list.isEmpty() ? " 已返回医院列表。" : "");
        }
        return result.resultMessage() == null ? "操作已完成。" : result.resultMessage();
    }

    private String actionPreparationFailureAnswer(AgentActionType actionType, RuntimeException ex) {
        if (isTransactionRollbackFailure(ex)) {
            return "Agent 操作暂时没有完成，但不会影响已经保存的健康数据。你可以稍后再试，或直接查看健康记录、提醒和趋势。";
        }
        String message = ex.getMessage() == null || ex.getMessage().isBlank()
                ? "参数不完整或暂时无法处理"
                : ex.getMessage();
        if (actionType == AgentActionType.RECORD_HEALTH_DATA || actionType == AgentActionType.CREATE_HEALTH_PLAN) {
            return message;
        }
        return message + "。如果情况紧急，请及时联系医生或使用 SOS。";
    }

    private boolean isTransactionRollbackFailure(Throwable throwable) {
        Throwable current = throwable;
        while (current != null) {
            String text = (current.getClass().getName() + " " + safeStatusText(current.getMessage()))
                    .toLowerCase();
            if (text.contains("rollback-only") || text.contains("unexpectedrollback")) {
                return true;
            }
            current = current.getCause();
        }
        return false;
    }

    public List<AgentSessionVO> listSessions() {
        Long userId = SecurityUtils.currentUserId();
        return conversationMapper.selectList(new LambdaQueryWrapper<AgentConversation>()
                        .eq(AgentConversation::getUserId, userId)
                        .eq(AgentConversation::getStatus, "active")
                        .and(wrapper -> wrapper.eq(AgentConversation::getActorRole, "PATIENT")
                                .or()
                                .isNull(AgentConversation::getActorRole))
                        .and(wrapper -> wrapper.eq(AgentConversation::getTargetUserId, userId)
                                .or()
                                .isNull(AgentConversation::getTargetUserId))
                        .orderByDesc(AgentConversation::getUpdatedAt)
                        .orderByDesc(AgentConversation::getId))
                .stream()
                .map(item -> new AgentSessionVO(item.getId(), item.getTitle(), item.getUpdatedAt()))
                .toList();
    }

    public List<AgentMessageVO> listMessages(Long sessionId) {
        Long userId = SecurityUtils.currentUserId();
        requireConversation(userId, userId, "PATIENT", sessionId);
        return messageMapper.selectList(new LambdaQueryWrapper<AgentMessage>()
                        .eq(AgentMessage::getConversationId, sessionId)
                        .eq(AgentMessage::getUserId, userId)
                        .orderByAsc(AgentMessage::getCreatedAt)
                        .orderByAsc(AgentMessage::getId))
                .stream()
                .map(item -> new AgentMessageVO(item.getId(), item.getRole(), item.getContent(), item.getCreatedAt()))
                .toList();
    }

    @Transactional
    public void deleteSession(Long sessionId) {
        Long userId = SecurityUtils.currentUserId();
        requireConversation(userId, userId, "PATIENT", sessionId);
        conversationMapper.update(null, new LambdaUpdateWrapper<AgentConversation>()
                .eq(AgentConversation::getId, sessionId)
                .eq(AgentConversation::getUserId, userId)
                .set(AgentConversation::getStatus, "deleted")
                .set(AgentConversation::getUpdatedAt, LocalDateTime.now()));
    }

    private AgentConversation resolveConversation(
            Long actorUserId,
            Long targetUserId,
            String actorRole,
            Long sessionId,
            String firstMessage
    ) {
        if (sessionId != null) {
            return requireConversation(actorUserId, targetUserId, actorRole, sessionId);
        }
        AgentConversation conversation = new AgentConversation();
        conversation.setUserId(actorUserId);
        conversation.setTargetUserId(targetUserId);
        conversation.setActorRole(actorRole);
        conversation.setTitle(buildTitle(firstMessage));
        conversation.setStatus("active");
        conversationMapper.insert(conversation);
        return conversation;
    }

    private AgentConversation requireConversation(Long actorUserId, Long targetUserId, String actorRole, Long sessionId) {
        if (sessionId == null || sessionId <= 0) {
            throw new IllegalArgumentException("会话不存在");
        }
        LambdaQueryWrapper<AgentConversation> query = new LambdaQueryWrapper<AgentConversation>()
                .eq(AgentConversation::getId, sessionId)
                .eq(AgentConversation::getUserId, actorUserId)
                .eq(AgentConversation::getStatus, "active");
        if (isPatientActor(actorRole)) {
            query.and(wrapper -> wrapper.eq(AgentConversation::getActorRole, "PATIENT")
                            .or()
                            .isNull(AgentConversation::getActorRole))
                    .and(wrapper -> wrapper.eq(AgentConversation::getTargetUserId, targetUserId)
                            .or()
                            .isNull(AgentConversation::getTargetUserId));
        } else {
            query.eq(AgentConversation::getActorRole, actorRole)
                    .eq(AgentConversation::getTargetUserId, targetUserId);
        }
        AgentConversation conversation = conversationMapper.selectOne(query);
        if (conversation == null) {
            throw new IllegalArgumentException("会话不存在");
        }
        return conversation;
    }

    private AgentMessage saveMessage(Long conversationId, Long userId, String role, String content) {
        AgentMessage message = new AgentMessage();
        message.setConversationId(conversationId);
        message.setUserId(userId);
        message.setRole(role);
        message.setContent(content);
        messageMapper.insert(message);
        return message;
    }

    private void touchConversation(Long conversationId) {
        conversationMapper.update(null, new LambdaUpdateWrapper<AgentConversation>()
                .eq(AgentConversation::getId, conversationId)
                .set(AgentConversation::getUpdatedAt, LocalDateTime.now()));
    }

    private List<AgentChatTurn> buildTurns(Long conversationId) {
        List<AgentMessage> recent = messageMapper.selectList(new LambdaQueryWrapper<AgentMessage>()
                .eq(AgentMessage::getConversationId, conversationId)
                .orderByDesc(AgentMessage::getCreatedAt)
                .orderByDesc(AgentMessage::getId)
                .last("LIMIT " + RECENT_MESSAGE_LIMIT));
        Collections.reverse(recent);
        return recent.stream()
                .map(message -> new AgentChatTurn(message.getRole(), message.getContent()))
                .toList();
    }

    private String buildUserContext(Long targetUserId, String actorRole) {
        List<String> lines = new ArrayList<>();
        if (!isPatientActor(actorRole)) {
            lines.add("当前提问者是家属/照护者，不是患者本人。以下健康数据属于被照护者，回答必须使用照护者视角。");
        }
        try {
            UserProfileVO profile = userService.getProfileByUserId(targetUserId);
            lines.add("基础资料：" + formatUserProfile(profile));
        } catch (RuntimeException ignored) {
            lines.add("用户资料：暂不可用");
        }
        try {
            HealthProfileVO profile = userService.getHealthProfileByUserId(targetUserId);
            lines.add("健康档案：" + formatHealthProfile(profile));
        } catch (RuntimeException ignored) {
            lines.add("健康档案：暂不可用");
        }
        try {
            HealthGoalVO goal = userService.getHealthGoalByUserId(targetUserId);
            lines.add("健康目标：" + formatHealthGoal(goal));
        } catch (RuntimeException ignored) {
            lines.add("健康目标：暂不可用");
        }
        try {
            UserSettingVO setting = userService.getSettingsByUserId(targetUserId);
            lines.add("用户设置：" + formatUserSetting(setting));
            if (Boolean.TRUE.equals(setting.simpleMode())) {
                lines.add("简洁模式要求：回答控制在 3 个短段落以内，先给结论和下一步行动，减少背景解释、扩展建议和重复提醒。");
            }
        } catch (RuntimeException ignored) {
            lines.add("用户设置：暂不可用");
        }
        try {
            HealthSummaryVO summary = healthService.getSummaryByUserId(targetUserId);
            lines.add("健康摘要：" + summary.status() + "，健康分 " + summary.healthScore()
                    + "，指标 " + summary.metrics());
        } catch (RuntimeException ignored) {
            lines.add("健康摘要：暂不可用");
        }
        try {
            List<HealthRecordVO> records = healthService.listRecentRecordsByUserId(targetUserId, REMINDER_CONTEXT_LIMIT);
            lines.add("最新健康记录：" + records.stream().map(this::formatRecord).toList());
        } catch (RuntimeException ignored) {
            lines.add("最新健康记录：暂不可用");
        }
        try {
            List<ReminderVO> reminders = reminderService.listPendingRemindersByUserId(targetUserId, REMINDER_CONTEXT_LIMIT);
            lines.add("未完成待办/提醒：" + reminders.stream().map(this::formatReminder).toList());
        } catch (RuntimeException ignored) {
            lines.add("未完成待办/提醒：暂不可用");
        }
        return String.join("\n", lines);
    }

    private String formatUserProfile(UserProfileVO profile) {
        return "用户ID " + safe(profile.id())
                + "，账号 " + safe(profile.username())
                + "，昵称 " + safe(profile.nickname())
                + "，年龄 " + safe(profile.age())
                + "，性别 " + safe(profile.gender())
                + "，手机号 " + safe(profile.phone())
                + "，邮箱 " + safe(profile.email());
    }

    private String formatHealthProfile(HealthProfileVO profile) {
        return "身高 " + withUnit(profile.height(), "cm")
                + "，体重 " + withUnit(profile.weight(), "kg")
                + "，BMI " + safe(profile.bmi())
                + "，慢病 " + safeList(profile.chronicDiseases())
                + "，过敏 " + safe(profile.allergies())
                + "，病史 " + safe(profile.medicalHistory())
                + "，设备 " + safe(profile.device());
    }

    private String formatHealthGoal(HealthGoalVO goal) {
        return "步数目标 " + safe(goal.stepsTarget())
                + "，步数备注 " + safe(goal.stepsNote())
                + "，睡眠目标 " + safe(goal.sleepTarget())
                + "，睡眠备注 " + safe(goal.sleepNote())
                + "，血压目标 " + safe(goal.bloodPressureTarget())
                + "，血压备注 " + safe(goal.bloodPressureNote());
    }

    private String formatUserSetting(UserSettingVO setting) {
        return "字体比例 " + safe(setting.fontScale())
                + "，通知 " + enabledText(setting.notificationEnabled())
                + "，大触控 " + enabledText(setting.largeTouchTarget())
                + "，简洁模式 " + enabledText(setting.simpleMode());
    }

    private String formatRecord(HealthRecordVO record) {
        String value = "blood_pressure".equals(record.type()) && record.systolic() != null && record.diastolic() != null
                ? record.systolic() + "/" + record.diastolic()
                : safe(record.value());
        return typeName(record.type()) + " " + value + safe(record.unit()) + "，状态 " + safe(record.status())
                + "，记录时间 " + safe(record.recordedAt());
    }

    private String formatReminder(ReminderVO reminder) {
        return "待办标题：" + safe(reminder.title())
                + "，提醒时间 " + safe(reminder.remindAt())
                + "，重复 " + safe(reminder.repeatType());
    }

    private String typeName(String type) {
        return switch (type == null ? "" : type) {
            case "blood_pressure" -> "血压";
            case "blood_glucose" -> "血糖";
            case "heart_rate" -> "心率";
            case "weight" -> "体重";
            default -> "其他";
        };
    }

    private List<WebSearchResult> searchIfNeeded(String userMessage) {
        if (!toolDecisionService.shouldUseWebSearch(userMessage)) {
            return List.of();
        }
        try {
            return toolExecutor.webSearch(userMessage);
        } catch (RuntimeException ignored) {
            return List.of();
        }
    }

    private List<AgentCitationVO> buildCitations(List<WebSearchResult> webSearchResults) {
        if (webSearchResults == null || webSearchResults.isEmpty()) {
            return List.of();
        }
        return webSearchResults.stream()
                .map(result -> new AgentCitationVO(
                        safeCitation(result.title()),
                        safeCitation(result.url()),
                        safeCitation(result.source()),
                        safeCitation(result.snippet())
                ))
                .limit(5)
                .toList();
    }

    private List<String> buildSuggestions(String message, String actorRole) {
        if (!isPatientActor(actorRole)) {
            if (message.contains("血压")) {
                return List.of("查看血压趋势", "查看最近记录", "提醒家人复测");
            }
            if (message.contains("血糖")) {
                return List.of("查看血糖趋势", "查看最近记录", "联系医生咨询");
            }
            if (message.contains("药") || message.contains("提醒")) {
                return List.of("查看提醒完成情况", "联系家人确认", "咨询医生建议");
            }
            return List.of("查看健康摘要", "查看趋势", "咨询医生建议");
        }
        if (message.contains("血压")) {
            return List.of("查看血压趋势", "记录今日血压", "设置测量提醒");
        }
        if (message.contains("血糖")) {
            return List.of("查看血糖趋势", "记录餐后血糖", "记录饮食备注");
        }
        if (message.contains("药") || message.contains("提醒")) {
            return List.of("创建服药提醒", "查看全部提醒", "补充药品剂量");
        }
        return List.of("查看健康摘要", "记录健康数据", "设置提醒");
    }

    private boolean isPatientActor(String actorRole) {
        return actorRole == null || "PATIENT".equals(actorRole);
    }

    private boolean mutatesPatientData(AgentActionType actionType) {
        return actionType == AgentActionType.RECORD_HEALTH_DATA
                || actionType == AgentActionType.CREATE_HEALTH_PLAN;
    }

    private String buildTitle(String text) {
        String compact = text.replaceAll("\\s+", " ").trim();
        if (compact.length() <= 18) {
            return compact;
        }
        return compact.substring(0, 18) + "...";
    }

    private String safe(Object value) {
        if (value == null) {
            return "未填写";
        }
        String text = value.toString();
        return text.isBlank() ? "未填写" : text;
    }

    private String safe(Object primary, Object fallback) {
        if (primary != null && !primary.toString().isBlank()) {
            return primary.toString();
        }
        return safe(fallback);
    }

    private String safeCitation(Object value) {
        return value == null ? "" : value.toString();
    }

    private String safeList(List<?> values) {
        return values == null || values.isEmpty() ? "未填写" : values.toString();
    }

    private String withUnit(Object value, String unit) {
        return value == null ? "未填写" : value + unit;
    }

    private String enabledText(Boolean value) {
        return Boolean.TRUE.equals(value) ? "开启" : "关闭";
    }

    private void logLlmFailure(
            RuntimeException ex,
            Long actorUserId,
            Long targetUserId,
            String actorRole,
            Long conversationId
    ) {
        log.warn(
                "Agent LLM call failed: exceptionType={}, httpStatus={}, actorUserId={}, targetUserId={}, "
                        + "actorRole={}, conversationId={}, upstreamSummary={}",
                ex.getClass().getName(),
                extractHttpStatus(ex),
                actorUserId,
                targetUserId,
                actorRole,
                conversationId,
                summarizeThrowable(ex),
                ex
        );
    }

    private String extractHttpStatus(Throwable throwable) {
        Throwable current = throwable;
        while (current != null) {
            String reflectedStatus = extractStatusByReflection(current);
            if (!reflectedStatus.isBlank()) {
                return reflectedStatus;
            }
            String messageStatus = extractStatusFromText(current.getMessage());
            if (!messageStatus.isBlank()) {
                return messageStatus;
            }
            current = current.getCause();
        }
        return "unknown";
    }

    private String extractStatusByReflection(Throwable throwable) {
        for (String methodName : List.of("statusCode", "getStatusCode", "code", "getCode")) {
            try {
                Method method = throwable.getClass().getMethod(methodName);
                Object value = method.invoke(throwable);
                if (value instanceof Number number) {
                    return String.valueOf(number.intValue());
                }
                String status = extractStatusFromText(safeStatusText(value));
                if (!status.isBlank()) {
                    return status;
                }
            } catch (ReflectiveOperationException | SecurityException ignored) {
                // Upstream client exceptions expose HTTP status through different optional APIs.
            }
        }
        return "";
    }

    private String extractStatusFromText(String text) {
        if (text == null || text.isBlank()) {
            return "";
        }
        Matcher matcher = HTTP_STATUS_PATTERN.matcher(text);
        return matcher.find() ? matcher.group(1) : "";
    }

    private String safeStatusText(Object value) {
        return value == null ? "" : value.toString();
    }

    private String summarizeThrowable(Throwable throwable) {
        StringBuilder summary = new StringBuilder();
        Throwable current = throwable;
        while (current != null && summary.length() < UPSTREAM_ERROR_SUMMARY_LIMIT) {
            String message = current.getMessage();
            if (message != null && !message.isBlank()) {
                if (!summary.isEmpty()) {
                    summary.append(" | caused by ");
                }
                summary.append(current.getClass().getSimpleName())
                        .append(": ")
                        .append(message.replaceAll("\\s+", " ").trim());
            }
            current = current.getCause();
        }
        if (summary.isEmpty()) {
            return "no upstream error message";
        }
        if (summary.length() <= UPSTREAM_ERROR_SUMMARY_LIMIT) {
            return summary.toString();
        }
        return summary.substring(0, UPSTREAM_ERROR_SUMMARY_LIMIT) + "...";
    }
}

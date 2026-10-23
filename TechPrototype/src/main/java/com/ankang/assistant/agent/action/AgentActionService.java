package com.ankang.assistant.agent.action;

import com.ankang.assistant.agent.tool.AgentToolExecutor;
import com.ankang.assistant.config.SecurityUtils;
import com.ankang.assistant.family.service.FamilyPermissionService;
import com.ankang.assistant.family.service.FamilyService;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Map;
import java.util.UUID;

@Service
public class AgentActionService {

    private static final Logger log = LoggerFactory.getLogger(AgentActionService.class);
    private static final int DEFAULT_EXPIRE_MINUTES = 10;
    private static final TypeReference<Map<String, Object>> MAP_TYPE = new TypeReference<>() {
    };

    private final AgentActionMapper actionMapper;
    private final AgentToolExecutor toolExecutor;
    private final AgentActionValidator validator;
    private final ObjectMapper objectMapper;
    private final FamilyPermissionService familyPermissionService;

    public AgentActionService(
            AgentActionMapper actionMapper,
            AgentToolExecutor toolExecutor,
            AgentActionValidator validator,
            ObjectMapper objectMapper,
            FamilyPermissionService familyPermissionService
    ) {
        this.actionMapper = actionMapper;
        this.toolExecutor = toolExecutor;
        this.validator = validator;
        this.objectMapper = objectMapper;
        this.familyPermissionService = familyPermissionService;
    }

    @Transactional
    public AgentActionVO createPendingAction(
            Long actorUserId,
            Long targetUserId,
            String actorRole,
            Long sessionId,
            AgentActionRequest request
    ) {
        ensureActionPermission(actorUserId, targetUserId, actorRole);
        validator.validateForCreation(request, actorRole);
        AgentAction action = buildAction(actorUserId, targetUserId, actorRole, sessionId, request);
        action.setStatus(AgentActionStatus.PENDING_CONFIRMATION.name());
        actionMapper.insert(action);
        log.info("Agent action created: actionId={}, userId={}, targetUserId={}, actionType={}, status={}",
                action.getActionId(), actorUserId, targetUserId, action.getActionType(), action.getStatus());
        return AgentActionVO.pending(
                action.getActionId(),
                request.actionType(),
                request.title(),
                request.description(),
                request.requiresConfirmation(),
                request.payload()
        );
    }

    @Transactional
    public AgentActionVO executeImmediate(
            Long actorUserId,
            Long targetUserId,
            String actorRole,
            Long sessionId,
            AgentActionRequest request
    ) {
        ensureActionPermission(actorUserId, targetUserId, actorRole);
        validator.validateForCreation(request, actorRole);
        AgentAction action = buildAction(actorUserId, targetUserId, actorRole, sessionId, request);
        action.setStatus(AgentActionStatus.PENDING_CONFIRMATION.name());
        actionMapper.insert(action);
        return execute(action);
    }

    @Transactional
    public AgentActionVO confirm(AgentActionConfirmRequest request) {
        Long currentUserId = SecurityUtils.currentUserId();
        AgentAction action = actionMapper.selectOne(new LambdaQueryWrapper<AgentAction>()
                .eq(AgentAction::getActionId, request.actionId())
                .eq(AgentAction::getUserId, currentUserId)
                .last("LIMIT 1"));
        if (action == null) {
            throw new IllegalArgumentException("待确认 Action 不存在");
        }
        ensureActionPermission(action.getUserId(), action.getTargetUserId(), action.getActorRole());
        if (action.getExpiresAt() != null
                && action.getExpiresAt().isBefore(LocalDateTime.now())
                && AgentActionStatus.PENDING_CONFIRMATION.name().equals(action.getStatus())) {
            action.setStatus(AgentActionStatus.EXPIRED.name());
            action.setErrorMessage("Action 已过期，请重新发起");
            actionMapper.updateById(action);
            log.info("Agent action expired: actionId={}, userId={}, actionType={}, status={}",
                    action.getActionId(), action.getUserId(), action.getActionType(), action.getStatus());
            return toVO(action, "Action 已过期，请重新发起");
        }
        AgentActionStatus status = AgentActionStatus.valueOf(action.getStatus());
        if (status == AgentActionStatus.EXECUTED
                || status == AgentActionStatus.CANCELLED
                || status == AgentActionStatus.EXPIRED
                || status == AgentActionStatus.FAILED) {
            return toVO(action, statusMessage(status, action));
        }
        if (!Boolean.TRUE.equals(request.confirmed())) {
            action.setStatus(AgentActionStatus.CANCELLED.name());
            action.setErrorMessage(null);
            actionMapper.updateById(action);
            log.info("Agent action cancelled: actionId={}, userId={}, actionType={}, status={}",
                    action.getActionId(), action.getUserId(), action.getActionType(), action.getStatus());
            return toVO(action, "已取消该操作");
        }
        return execute(action);
    }

    private AgentActionVO execute(AgentAction action) {
        AgentActionType actionType = AgentActionType.valueOf(action.getActionType());
        Map<String, Object> payload = readPayload(action.getPayload());
        AgentActionExecutionContext context = new AgentActionExecutionContext(
                action.getActionId(),
                action.getUserId(),
                action.getTargetUserId(),
                action.getSessionId(),
                action.getActorRole()
        );
        try {
            validator.validateForExecution(actionType, payload, context);
            AgentActionResult result = toolExecutor.executeAction(actionType, context, payload);
            action.setResult(writeJson(result.data()));
            action.setErrorMessage(result.success() ? null : result.resultMessage());
            action.setStatus(result.success()
                    ? AgentActionStatus.EXECUTED.name()
                    : AgentActionStatus.FAILED.name());
            actionMapper.updateById(action);
            log.info("Agent action finished: actionId={}, userId={}, actionType={}, status={}",
                    action.getActionId(), action.getUserId(), action.getActionType(), action.getStatus());
            return AgentActionVO.result(
                    action.getActionId(),
                    actionType,
                    AgentActionStatus.valueOf(action.getStatus()),
                    payload,
                    result.resultMessage(),
                    result.data()
            );
        } catch (RuntimeException ex) {
            action.setStatus(AgentActionStatus.FAILED.name());
            action.setErrorMessage(safeMessage(ex));
            actionMapper.updateById(action);
            log.warn("Agent action failed: actionId={}, userId={}, actionType={}, status={}, error={}",
                    action.getActionId(), action.getUserId(), action.getActionType(), action.getStatus(),
                    action.getErrorMessage(), ex);
            return AgentActionVO.result(
                    action.getActionId(),
                    actionType,
                    AgentActionStatus.FAILED,
                    payload,
                    "操作执行失败：" + action.getErrorMessage(),
                    Map.of()
            );
        }
    }

    private AgentAction buildAction(
            Long actorUserId,
            Long targetUserId,
            String actorRole,
            Long sessionId,
            AgentActionRequest request
    ) {
        AgentAction action = new AgentAction();
        action.setActionId("act_" + UUID.randomUUID().toString().replace("-", ""));
        action.setUserId(actorUserId);
        action.setTargetUserId(targetUserId == null ? actorUserId : targetUserId);
        action.setActorRole(actorRole == null || actorRole.isBlank() ? "PATIENT" : actorRole);
        action.setSessionId(sessionId);
        action.setActionType(request.actionType().name());
        action.setPayload(writeJson(request.payload()));
        action.setExpiresAt(LocalDateTime.now().plusMinutes(DEFAULT_EXPIRE_MINUTES));
        return action;
    }

    private AgentActionVO toVO(AgentAction action, String resultMessage) {
        AgentActionType actionType = AgentActionType.valueOf(action.getActionType());
        AgentActionStatus status = AgentActionStatus.valueOf(action.getStatus());
        return AgentActionVO.result(
                action.getActionId(),
                actionType,
                status,
                readPayload(action.getPayload()),
                resultMessage,
                readPayload(action.getResult())
        );
    }

    private String statusMessage(AgentActionStatus status, AgentAction action) {
        return switch (status) {
            case EXECUTED -> "该操作已执行，无需重复确认";
            case CANCELLED -> "该操作已取消";
            case EXPIRED -> "Action 已过期，请重新发起";
            case FAILED -> action.getErrorMessage() == null || action.getErrorMessage().isBlank()
                    ? "该操作执行失败"
                    : "该操作执行失败：" + action.getErrorMessage();
            case PENDING_CONFIRMATION -> "等待确认";
        };
    }

    private String writeJson(Map<String, Object> value) {
        try {
            return objectMapper.writeValueAsString(value == null ? Map.of() : value);
        } catch (JsonProcessingException ex) {
            throw new IllegalStateException("Action 参数序列化失败", ex);
        }
    }

    private Map<String, Object> readPayload(String json) {
        if (json == null || json.isBlank()) {
            return Map.of();
        }
        try {
            return objectMapper.readValue(json, MAP_TYPE);
        } catch (JsonProcessingException ex) {
            return Map.of();
        }
    }

    private String safeMessage(RuntimeException ex) {
        String message = ex.getMessage();
        if (message == null || message.isBlank()) {
            return ex.getClass().getSimpleName();
        }
        return message.length() <= 180 ? message : message.substring(0, 180);
    }

    private void ensureActionPermission(Long actorUserId, Long targetUserId, String actorRole) {
        Long safeTargetUserId = targetUserId == null ? actorUserId : targetUserId;
        if ("CAREGIVER".equals(actorRole)) {
            if (!familyPermissionService.hasCaregiverAccess(actorUserId, safeTargetUserId, FamilyService.ASK_AGENT)) {
                throw new IllegalArgumentException("未获得该被照护者的 Agent 授权");
            }
            return;
        }
        if (actorUserId == null || !actorUserId.equals(safeTargetUserId)) {
            throw new IllegalArgumentException("无权执行该 Agent Action");
        }
    }
}

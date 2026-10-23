package com.ankang.assistant.eventmesh.service;

import com.ankang.assistant.emergency.entity.EmergencyEvent;
import com.ankang.assistant.emergency.mapper.EmergencyEventMapper;
import com.ankang.assistant.eventmesh.entity.HealthEvent;
import com.ankang.assistant.eventmesh.entity.HealthEventTimeline;
import com.ankang.assistant.eventmesh.event.HealthRecordCreatedEvent;
import com.ankang.assistant.eventmesh.mapper.HealthEventMapper;
import com.ankang.assistant.eventmesh.mapper.HealthEventTimelineMapper;
import com.ankang.assistant.eventmesh.vo.RiskAssessment;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

import java.time.LocalDateTime;
import java.util.UUID;

/** 健康事件异步编排器：状态机、风险评估、SSE 推送和 SOS 预案在此串联。 */
@Service
public class HealthEventProcessor {

    private static final Logger log = LoggerFactory.getLogger(HealthEventProcessor.class);

    private final HealthEventMapper healthEventMapper;
    private final HealthEventTimelineMapper timelineMapper;
    private final EmergencyEventMapper emergencyEventMapper;
    private final RiskEngineService riskEngineService;
    private final HealthEventQueryService queryService;
    private final HealthEventStreamService streamService;

    public HealthEventProcessor(
            HealthEventMapper healthEventMapper,
            HealthEventTimelineMapper timelineMapper,
            EmergencyEventMapper emergencyEventMapper,
            RiskEngineService riskEngineService,
            HealthEventQueryService queryService,
            HealthEventStreamService streamService
    ) {
        this.healthEventMapper = healthEventMapper;
        this.timelineMapper = timelineMapper;
        this.emergencyEventMapper = emergencyEventMapper;
        this.riskEngineService = riskEngineService;
        this.queryService = queryService;
        this.streamService = streamService;
    }

    @Async("healthEventExecutor")
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onHealthRecordCreated(HealthRecordCreatedEvent sourceEvent) {
        HealthEvent event = createEvent(sourceEvent);
        EventProcessingState state = EventProcessingState.RECEIVED;
        try {
            state = transition(event, state, EventProcessingState.PUBLISHED,
                    "发布 HealthRecordCreatedEvent");
            state = transition(event, state, EventProcessingState.ASSESSING,
                    "混合风险引擎开始评估医学规则、30 天个人基线、趋势与关联指标");

            RiskAssessment assessment = riskEngineService.assess(
                    sourceEvent.userId(), sourceEvent.healthRecordId());
            event.setRiskLevel(assessment.level());
            event.setRiskScore(assessment.score());
            event.setSummary(assessment.summary());
            event.setReasonsJson(queryService.serializeReasons(assessment.reasons()));
            healthEventMapper.updateById(event);
            state = transition(event, state, EventProcessingState.ALERTED,
                    "风险评估完成：" + assessment.level() + "（" + assessment.score() + " 分）");

            if ("high".equals(assessment.level())) {
                try {
                    EmergencyEvent sosPlan = createSosPlan(sourceEvent.userId(), event);
                    event.setSosEventId(sosPlan.getId());
                    healthEventMapper.updateById(event);
                    state = transition(event, state, EventProcessingState.SOS_PREPARED,
                            "已创建 SOS 应急预案（仅预案，未发送真实通知）");
                } catch (Exception sosException) {
                    // SOS 预案是高风险提醒的辅助能力。即使预案暂时无法落库，
                    // 也必须继续把已经完成的风险评估结果推送给用户。
                    appendTimeline(event.getId(), "sos_prepare_failed",
                            "SOS 预案准备失败，风险结果仍会正常推送");
                    log.warn("Health event {} SOS plan preparation failed", event.getEventId(), sosException);
                }
            }

            state = transition(event, state, EventProcessingState.PUSHED,
                    "风险结果已发送到实时推送通道");
            event.setProcessedAt(LocalDateTime.now());
            state = transition(event, state, EventProcessingState.COMPLETED, "事件处理闭环完成");
            streamService.publish(sourceEvent.userId(), queryService.toVO(event, true));
        } catch (Exception ex) {
            event.setStatus(EventProcessingState.FAILED.value());
            event.setProcessedAt(LocalDateTime.now());
            event.setSummary("事件处理失败，请稍后重试或查看服务日志");
            healthEventMapper.updateById(event);
            appendTimeline(event.getId(), EventProcessingState.FAILED.value(),
                    "处理失败：" + safeMessage(ex));
            log.error("Health event {} processing failed at state {}", event.getEventId(), state, ex);
        }
    }

    private HealthEvent createEvent(HealthRecordCreatedEvent sourceEvent) {
        HealthEvent event = new HealthEvent();
        event.setEventId(UUID.randomUUID().toString());
        event.setUserId(sourceEvent.userId());
        event.setEventType("HealthRecordCreatedEvent");
        event.setAggregateId(sourceEvent.healthRecordId());
        event.setStatus(EventProcessingState.RECEIVED.value());
        event.setOccurredAt(sourceEvent.occurredAt());
        healthEventMapper.insert(event);
        appendTimeline(event.getId(), EventProcessingState.RECEIVED.value(), "健康数据已保存");
        return event;
    }

    private EventProcessingState transition(
            HealthEvent event,
            EventProcessingState current,
            EventProcessingState next,
            String message
    ) {
        if (!current.canTransitionTo(next)) {
            throw new IllegalStateException("非法事件状态迁移：" + current + " -> " + next);
        }
        event.setStatus(next.value());
        healthEventMapper.updateById(event);
        appendTimeline(event.getId(), next.value(), message);
        return next;
    }

    private EmergencyEvent createSosPlan(Long userId, HealthEvent healthEvent) {
        EmergencyEvent existing = emergencyEventMapper.selectOne(new LambdaQueryWrapper<EmergencyEvent>()
                .eq(EmergencyEvent::getUserId, userId)
                .eq(EmergencyEvent::getStatus, "prepared")
                .ge(EmergencyEvent::getCreatedAt, LocalDateTime.now().minusMinutes(5))
                .orderByDesc(EmergencyEvent::getCreatedAt)
                .orderByDesc(EmergencyEvent::getId)
                .last("LIMIT 1"));
        if (existing != null) {
            return existing;
        }
        EmergencyEvent event = new EmergencyEvent();
        LocalDateTime now = LocalDateTime.now();
        event.setUserId(userId);
        event.setClientEventId("risk-" + healthEvent.getEventId());
        event.setTriggeredAt(now);
        event.setLocationSource("unavailable");
        event.setMessage("健康事件 " + healthEvent.getEventId() + " 触发高风险 SOS 预案");
        event.setStatus("prepared");
        event.setContactsNotified(0);
        event.setCreatedAt(now);
        event.setUpdatedAt(now);
        emergencyEventMapper.insert(event);
        return event;
    }

    private void appendTimeline(Long healthEventId, String stage, String message) {
        HealthEventTimeline timeline = new HealthEventTimeline();
        timeline.setHealthEventId(healthEventId);
        timeline.setStage(stage);
        timeline.setMessage(message);
        timeline.setOccurredAt(LocalDateTime.now());
        timelineMapper.insert(timeline);
    }

    private String safeMessage(Exception ex) {
        String message = ex.getMessage();
        if (message == null || message.isBlank()) {
            return ex.getClass().getSimpleName();
        }
        return message.length() <= 180 ? message : message.substring(0, 180);
    }
}

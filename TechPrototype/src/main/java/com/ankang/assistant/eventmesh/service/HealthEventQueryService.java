package com.ankang.assistant.eventmesh.service;

import com.ankang.assistant.config.SecurityUtils;
import com.ankang.assistant.eventmesh.entity.HealthEvent;
import com.ankang.assistant.eventmesh.entity.HealthEventTimeline;
import com.ankang.assistant.eventmesh.mapper.HealthEventMapper;
import com.ankang.assistant.eventmesh.mapper.HealthEventTimelineMapper;
import com.ankang.assistant.eventmesh.vo.HealthEventTimelineVO;
import com.ankang.assistant.eventmesh.vo.HealthEventVO;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class HealthEventQueryService {

    private final HealthEventMapper healthEventMapper;
    private final HealthEventTimelineMapper timelineMapper;
    private final ObjectMapper objectMapper;

    public HealthEventQueryService(
            HealthEventMapper healthEventMapper,
            HealthEventTimelineMapper timelineMapper,
            ObjectMapper objectMapper
    ) {
        this.healthEventMapper = healthEventMapper;
        this.timelineMapper = timelineMapper;
        this.objectMapper = objectMapper;
    }

    public List<HealthEventVO> list(Integer limit) {
        Long userId = SecurityUtils.currentUserId();
        int safeLimit = Math.min(Math.max(limit == null ? 20 : limit, 1), 100);
        return healthEventMapper.selectList(new LambdaQueryWrapper<HealthEvent>()
                        .eq(HealthEvent::getUserId, userId)
                        .orderByDesc(HealthEvent::getOccurredAt)
                        .orderByDesc(HealthEvent::getId)
                        .last("LIMIT " + safeLimit))
                .stream()
                .map(event -> toVO(event, false))
                .toList();
    }

    public HealthEventVO detail(String eventId) {
        Long userId = SecurityUtils.currentUserId();
        HealthEvent event = healthEventMapper.selectOne(new LambdaQueryWrapper<HealthEvent>()
                .eq(HealthEvent::getEventId, eventId)
                .eq(HealthEvent::getUserId, userId));
        if (event == null) {
            throw new IllegalArgumentException("健康事件不存在");
        }
        return toVO(event, true);
    }

    HealthEventVO toVO(HealthEvent event, boolean includeTimeline) {
        List<HealthEventTimelineVO> timeline = includeTimeline
                ? timelineMapper.selectList(new LambdaQueryWrapper<HealthEventTimeline>()
                        .eq(HealthEventTimeline::getHealthEventId, event.getId())
                        .orderByAsc(HealthEventTimeline::getOccurredAt)
                        .orderByAsc(HealthEventTimeline::getId))
                    .stream()
                    .map(item -> new HealthEventTimelineVO(item.getStage(), item.getMessage(), item.getOccurredAt()))
                    .toList()
                : List.of();
        return new HealthEventVO(
                event.getEventId(),
                event.getEventType(),
                event.getAggregateId(),
                event.getStatus(),
                event.getRiskLevel(),
                event.getRiskScore(),
                event.getSummary(),
                parseReasons(event.getReasonsJson()),
                event.getSosEventId(),
                event.getOccurredAt(),
                event.getProcessedAt(),
                timeline
        );
    }

    String serializeReasons(List<String> reasons) {
        try {
            return objectMapper.writeValueAsString(reasons);
        } catch (JsonProcessingException ex) {
            throw new IllegalStateException("风险原因序列化失败", ex);
        }
    }

    private List<String> parseReasons(String reasonsJson) {
        if (reasonsJson == null || reasonsJson.isBlank()) {
            return List.of();
        }
        try {
            return objectMapper.readValue(reasonsJson, new TypeReference<>() { });
        } catch (JsonProcessingException ex) {
            return List.of("风险原因解析失败");
        }
    }
}

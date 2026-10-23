package com.ankang.assistant.eventmesh.service;

import com.ankang.assistant.emergency.entity.EmergencyEvent;
import com.ankang.assistant.emergency.mapper.EmergencyEventMapper;
import com.ankang.assistant.eventmesh.entity.HealthEvent;
import com.ankang.assistant.eventmesh.entity.HealthEventTimeline;
import com.ankang.assistant.eventmesh.event.HealthRecordCreatedEvent;
import com.ankang.assistant.eventmesh.mapper.HealthEventMapper;
import com.ankang.assistant.eventmesh.mapper.HealthEventTimelineMapper;
import com.ankang.assistant.eventmesh.vo.HealthEventVO;
import com.ankang.assistant.eventmesh.vo.RiskAssessment;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.atLeastOnce;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.reset;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class HealthEventProcessorTest {

    @Mock
    private HealthEventMapper healthEventMapper;
    @Mock
    private HealthEventTimelineMapper timelineMapper;
    @Mock
    private EmergencyEventMapper emergencyEventMapper;
    @Mock
    private RiskEngineService riskEngineService;
    @Mock
    private HealthEventQueryService queryService;
    @Mock
    private HealthEventStreamService streamService;

    private HealthEventProcessor processor;
    private HealthEventVO completedEvent;

    @BeforeEach
    void setUp() {
        processor = new HealthEventProcessor(
                healthEventMapper,
                timelineMapper,
                emergencyEventMapper,
                riskEngineService,
                queryService,
                streamService
        );
        completedEvent = new HealthEventVO(
                "event-id", "HealthRecordCreatedEvent", 99L, "completed",
                "high", 85, "检测到较高健康风险", List.of("心率明显异常"),
                501L, LocalDateTime.now(), LocalDateTime.now(), List.of()
        );
        lenient().doAnswer(invocation -> {
            HealthEvent event = invocation.getArgument(0);
            event.setId(100L);
            return 1;
        }).when(healthEventMapper).insert(any(HealthEvent.class));
        lenient().when(riskEngineService.assess(7L, 99L)).thenReturn(
                new RiskAssessment("high", 85, "本次录入心率 220 bpm，建议立即关注",
                        List.of("本次录入：心率处于明显异常状态（220 bpm）"))
        );
        lenient().when(queryService.serializeReasons(any())).thenReturn("[\"心率明显异常\"]");
        lenient().when(queryService.toVO(any(HealthEvent.class), eq(true))).thenReturn(completedEvent);
    }

    @Test
    void highRiskEventCreatesValidSosPlanAndCompletes() {
        doAnswer(invocation -> {
            EmergencyEvent event = invocation.getArgument(0);
            event.setId(501L);
            return 1;
        }).when(emergencyEventMapper).insert(any(EmergencyEvent.class));

        processor.onHealthRecordCreated(
                new HealthRecordCreatedEvent(7L, 99L, LocalDateTime.now())
        );

        ArgumentCaptor<EmergencyEvent> sosPlanCaptor = ArgumentCaptor.forClass(EmergencyEvent.class);
        verify(emergencyEventMapper).insert(sosPlanCaptor.capture());
        EmergencyEvent sosPlan = sosPlanCaptor.getValue();
        assertThat(sosPlan.getClientEventId()).startsWith("risk-");
        assertThat(sosPlan.getTriggeredAt()).isNotNull();
        assertThat(sosPlan.getLocationSource()).isEqualTo("unavailable");
        assertThat(sosPlan.getStatus()).isEqualTo("prepared");

        ArgumentCaptor<HealthEvent> healthEventCaptor = ArgumentCaptor.forClass(HealthEvent.class);
        verify(healthEventMapper, atLeastOnce()).updateById(healthEventCaptor.capture());
        assertThat(healthEventCaptor.getAllValues())
                .anyMatch(event -> "completed".equals(event.getStatus())
                        && Long.valueOf(501L).equals(event.getSosEventId()));
        verify(streamService).publish(7L, completedEvent);
    }

    @Test
    void sosPlanFailureDoesNotReplaceSuccessfulRiskAssessment() {
        doThrow(new IllegalStateException("SOS plan database unavailable"))
                .when(emergencyEventMapper).insert(any(EmergencyEvent.class));

        processor.onHealthRecordCreated(
                new HealthRecordCreatedEvent(7L, 99L, LocalDateTime.now())
        );

        ArgumentCaptor<HealthEvent> healthEventCaptor = ArgumentCaptor.forClass(HealthEvent.class);
        verify(healthEventMapper, atLeastOnce()).updateById(healthEventCaptor.capture());
        assertThat(healthEventCaptor.getAllValues())
                .anyMatch(event -> "completed".equals(event.getStatus())
                        && "high".equals(event.getRiskLevel())
                        && event.getSummary().contains("心率 220 bpm"));
        ArgumentCaptor<HealthEventTimeline> timelineCaptor =
                ArgumentCaptor.forClass(HealthEventTimeline.class);
        verify(timelineMapper, atLeastOnce()).insert(timelineCaptor.capture());
        assertThat(timelineCaptor.getAllValues())
                .anyMatch(item -> "sos_prepare_failed".equals(item.getStage()));
        verify(streamService).publish(7L, completedEvent);
    }

    @Test
    void nonHighRiskCompletesWithoutPreparingSos() {
        when(riskEngineService.assess(7L, 99L)).thenReturn(
                new RiskAssessment("medium", 45, "需要继续观察", List.of("指标轻度异常"))
        );

        processor.onHealthRecordCreated(
                new HealthRecordCreatedEvent(7L, 99L, LocalDateTime.now())
        );

        verify(emergencyEventMapper, never()).selectOne(any());
        verify(emergencyEventMapper, never()).insert(any(EmergencyEvent.class));
        verify(streamService).publish(7L, completedEvent);
    }

    @Test
    void highRiskReusesRecentPreparedSosPlan() {
        EmergencyEvent existing = new EmergencyEvent();
        existing.setId(777L);
        when(emergencyEventMapper.selectOne(any())).thenReturn(existing);

        processor.onHealthRecordCreated(
                new HealthRecordCreatedEvent(7L, 99L, LocalDateTime.now())
        );

        verify(emergencyEventMapper, never()).insert(any(EmergencyEvent.class));
        ArgumentCaptor<HealthEvent> eventCaptor = ArgumentCaptor.forClass(HealthEvent.class);
        verify(healthEventMapper, atLeastOnce()).updateById(eventCaptor.capture());
        assertThat(eventCaptor.getAllValues())
                .anyMatch(event -> Long.valueOf(777L).equals(event.getSosEventId()));
    }

    @Test
    void processingFailureUsesExceptionClassWhenMessageIsNull() {
        reset(riskEngineService);
        when(riskEngineService.assess(7L, 99L)).thenThrow(new IllegalStateException());

        processor.onHealthRecordCreated(
                new HealthRecordCreatedEvent(7L, 99L, LocalDateTime.now())
        );

        assertFailureTimelineContains("IllegalStateException");
    }

    @Test
    void processingFailureUsesExceptionClassWhenMessageIsBlank() {
        reset(riskEngineService);
        when(riskEngineService.assess(7L, 99L)).thenThrow(new IllegalStateException("   "));

        processor.onHealthRecordCreated(
                new HealthRecordCreatedEvent(7L, 99L, LocalDateTime.now())
        );

        assertFailureTimelineContains("IllegalStateException");
    }

    @Test
    void processingFailureTruncatesLongMessages() {
        reset(riskEngineService);
        String longMessage = "x".repeat(220);
        when(riskEngineService.assess(7L, 99L)).thenThrow(new IllegalStateException(longMessage));

        processor.onHealthRecordCreated(
                new HealthRecordCreatedEvent(7L, 99L, LocalDateTime.now())
        );

        ArgumentCaptor<HealthEventTimeline> timelineCaptor =
                ArgumentCaptor.forClass(HealthEventTimeline.class);
        verify(timelineMapper, atLeastOnce()).insert(timelineCaptor.capture());
        HealthEventTimeline failed = timelineCaptor.getAllValues().stream()
                .filter(item -> "failed".equals(item.getStage()))
                .findFirst()
                .orElseThrow();
        assertThat(failed.getMessage()).hasSize("处理失败：".length() + 180);
    }

    @Test
    void transitionRejectsIllegalStateChanges() throws Exception {
        var method = HealthEventProcessor.class.getDeclaredMethod(
                "transition",
                HealthEvent.class,
                EventProcessingState.class,
                EventProcessingState.class,
                String.class
        );
        method.setAccessible(true);

        assertThatThrownBy(() -> method.invoke(
                processor,
                new HealthEvent(),
                EventProcessingState.RECEIVED,
                EventProcessingState.COMPLETED,
                "skip required states"
        )).hasCauseInstanceOf(IllegalStateException.class);
    }

    private void assertFailureTimelineContains(String expected) {
        ArgumentCaptor<HealthEventTimeline> timelineCaptor =
                ArgumentCaptor.forClass(HealthEventTimeline.class);
        verify(timelineMapper, atLeastOnce()).insert(timelineCaptor.capture());
        assertThat(timelineCaptor.getAllValues())
                .anyMatch(item -> "failed".equals(item.getStage())
                        && item.getMessage().contains(expected));
    }
}

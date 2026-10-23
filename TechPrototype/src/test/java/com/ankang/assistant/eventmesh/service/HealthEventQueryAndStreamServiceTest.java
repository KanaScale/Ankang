package com.ankang.assistant.eventmesh.service;

import com.ankang.assistant.config.JwtService;
import com.ankang.assistant.eventmesh.entity.HealthEvent;
import com.ankang.assistant.eventmesh.entity.HealthEventTimeline;
import com.ankang.assistant.eventmesh.mapper.HealthEventMapper;
import com.ankang.assistant.eventmesh.mapper.HealthEventTimelineMapper;
import com.ankang.assistant.eventmesh.vo.HealthEventVO;
import com.baomidou.mybatisplus.core.MybatisConfiguration;
import com.baomidou.mybatisplus.core.metadata.TableInfoHelper;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.ibatis.builder.MapperBuilderAssistant;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class HealthEventQueryAndStreamServiceTest {

    @Mock HealthEventMapper healthEventMapper;
    @Mock HealthEventTimelineMapper timelineMapper;

    private HealthEventQueryService queryService;

    @BeforeEach
    void setUp() {
        MapperBuilderAssistant assistant = new MapperBuilderAssistant(new MybatisConfiguration(), "");
        TableInfoHelper.initTableInfo(assistant, HealthEvent.class);
        TableInfoHelper.initTableInfo(assistant, HealthEventTimeline.class);
        queryService = new HealthEventQueryService(healthEventMapper, timelineMapper, new ObjectMapper());
        JwtService.JwtUser principal = new JwtService.JwtUser(42L, "event-user");
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(principal, null, List.of())
        );
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void listsDetailsSerializesAndSafelyParsesReasons() {
        HealthEvent event = event();
        when(healthEventMapper.selectList(any())).thenReturn(List.of(event));
        assertThat(queryService.list(null)).singleElement()
                .extracting(HealthEventVO::eventId).isEqualTo("evt-1");
        assertThat(queryService.list(0)).hasSize(1);
        assertThat(queryService.list(999)).hasSize(1);

        HealthEventTimeline timeline = new HealthEventTimeline();
        timeline.setStage("risk");
        timeline.setMessage("evaluated");
        timeline.setOccurredAt(LocalDateTime.now());
        when(healthEventMapper.selectOne(any())).thenReturn(event);
        when(timelineMapper.selectList(any())).thenReturn(List.of(timeline));
        HealthEventVO detail = queryService.detail("evt-1");
        assertThat(detail.reasons()).containsExactly("异常心率");
        assertThat(detail.timeline()).singleElement()
                .extracting(item -> item.stage()).isEqualTo("risk");

        event.setReasonsJson(null);
        assertThat(queryService.toVO(event, false).reasons()).isEmpty();
        event.setReasonsJson("bad-json");
        assertThat(queryService.toVO(event, false).reasons()).containsExactly("风险原因解析失败");
        assertThat(queryService.serializeReasons(List.of("a"))).isEqualTo("[\"a\"]");

        when(healthEventMapper.selectOne(any())).thenReturn(null);
        assertThatThrownBy(() -> queryService.detail("missing")).hasMessageContaining("不存在");
    }

    @Test
    void wrapsReasonSerializationFailure() throws Exception {
        ObjectMapper failing = mock(ObjectMapper.class);
        when(failing.writeValueAsString(any())).thenThrow(new JsonProcessingException("fail") { });
        HealthEventQueryService service = new HealthEventQueryService(
                healthEventMapper, timelineMapper, failing
        );
        assertThatThrownBy(() -> service.serializeReasons(List.of("a")))
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    void subscribesPublishesAndRemovesBrokenEmitters() throws IOException {
        HealthEventStreamService service = new HealthEventStreamService();
        SseEmitter real = service.subscribe(42L);
        assertThat(real.getTimeout()).isPositive();

        SseEmitter healthy = mock(SseEmitter.class);
        SseEmitter broken = mock(SseEmitter.class);
        doThrow(new IOException("closed")).when(broken).send(any(SseEmitter.SseEventBuilder.class));
        ConcurrentHashMap<Long, Set<SseEmitter>> emitters = new ConcurrentHashMap<>();
        emitters.put(42L, ConcurrentHashMap.newKeySet());
        emitters.get(42L).add(healthy);
        emitters.get(42L).add(broken);
        ReflectionTestUtils.setField(service, "emitters", emitters);

        service.publish(42L, queryService.toVO(event(), false));
        verify(healthy).send(any(SseEmitter.SseEventBuilder.class));
        verify(broken).complete();
        assertThat(emitters.get(42L)).containsExactly(healthy);

        service.publish(7L, queryService.toVO(event(), false));
        ReflectionTestUtils.invokeMethod(service, "remove", 42L, healthy);
        assertThat(emitters).doesNotContainKey(42L);
        ReflectionTestUtils.invokeMethod(service, "remove", 99L, healthy);
    }

    private HealthEvent event() {
        HealthEvent event = new HealthEvent();
        event.setId(1L);
        event.setEventId("evt-1");
        event.setUserId(42L);
        event.setEventType("HealthRecordCreated");
        event.setAggregateId(10L);
        event.setStatus("completed");
        event.setRiskLevel("elevated");
        event.setRiskScore(60);
        event.setSummary("需要关注");
        event.setReasonsJson("[\"异常心率\"]");
        event.setOccurredAt(LocalDateTime.now());
        event.setProcessedAt(LocalDateTime.now());
        return event;
    }
}

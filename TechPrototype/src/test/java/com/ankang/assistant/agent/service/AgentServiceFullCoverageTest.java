package com.ankang.assistant.agent.service;

import com.ankang.assistant.agent.action.AgentActionRequest;
import com.ankang.assistant.agent.action.AgentActionService;
import com.ankang.assistant.agent.action.AgentActionStatus;
import com.ankang.assistant.agent.action.AgentActionType;
import com.ankang.assistant.agent.action.AgentActionVO;
import com.ankang.assistant.agent.action.AgentIntentParser;
import com.ankang.assistant.agent.dto.AgentChatDTO;
import com.ankang.assistant.agent.entity.AgentConversation;
import com.ankang.assistant.agent.entity.AgentMemory;
import com.ankang.assistant.agent.entity.AgentMessage;
import com.ankang.assistant.agent.gms.GmsMemoryClient;
import com.ankang.assistant.agent.llm.AgentLlmClient;
import com.ankang.assistant.agent.mapper.AgentConversationMapper;
import com.ankang.assistant.agent.mapper.AgentMemoryMapper;
import com.ankang.assistant.agent.mapper.AgentMessageMapper;
import com.ankang.assistant.agent.tool.AgentToolExecutor;
import com.ankang.assistant.config.JwtService;
import com.ankang.assistant.health.service.HealthService;
import com.ankang.assistant.reminder.service.ReminderService;
import com.ankang.assistant.user.service.UserService;
import com.baomidou.mybatisplus.core.MybatisConfiguration;
import com.baomidou.mybatisplus.core.metadata.TableInfoHelper;
import org.apache.ibatis.builder.MapperBuilderAssistant;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import java.lang.reflect.Method;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicLong;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class AgentServiceFullCoverageTest {

    @BeforeAll
    static void initMybatis() {
        MybatisConfiguration configuration = new MybatisConfiguration();
        TableInfoHelper.initTableInfo(new MapperBuilderAssistant(configuration, ""), AgentConversation.class);
        TableInfoHelper.initTableInfo(new MapperBuilderAssistant(configuration, ""), AgentMessage.class);
        TableInfoHelper.initTableInfo(new MapperBuilderAssistant(configuration, ""), AgentMemory.class);
    }

    @AfterEach
    void clearSecurity() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void sessionQueriesMessagesDeleteAndValidationAreCovered() {
        authenticate(42L);
        Fixtures f = fixtures();
        AgentConversation session = conversation(9L, 42L, 42L, "PATIENT");
        session.setTitle("test session");
        session.setUpdatedAt(LocalDateTime.now());
        AgentMessage message = new AgentMessage();
        message.setId(11L);
        message.setRole("assistant");
        message.setContent("answer");
        message.setCreatedAt(LocalDateTime.now());
        when(f.conversations.selectList(any())).thenReturn(List.of(session));
        when(f.conversations.selectOne(any())).thenReturn(session);
        when(f.messages.selectList(any())).thenReturn(List.of(message));

        assertThat(f.service.listSessions()).singleElement().extracting("id").isEqualTo(9L);
        assertThat(f.service.listMessages(9L)).singleElement().extracting("content").isEqualTo("answer");
        f.service.deleteSession(9L);
        verify(f.conversations).update(any(), any());

        when(f.conversations.selectOne(any())).thenReturn(null);
        assertThatThrownBy(() -> f.service.listMessages(9L))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> f.service.listMessages(0L))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void caregiverChatUsesExistingConversationAndHandlesLlmFailure() {
        Fixtures f = fixtures();
        AgentConversation session = conversation(15L, 8L, 42L, "CAREGIVER");
        when(f.conversations.selectOne(any())).thenReturn(session);
        when(f.messages.selectList(any())).thenReturn(List.of());
        when(f.llm.chat(any(), any())).thenThrow(new IllegalStateException("HTTP status 503 unavailable"));
        when(f.gms.searchMemories(42L, "health question")).thenReturn(List.of());

        var reply = f.service.chatForCaregiver(8L, 42L, new AgentChatDTO(15L, "health question"));

        assertThat(reply.sessionId()).isEqualTo(15L);
        assertThat(reply.answer()).isNotBlank();
        verify(f.gms).searchMemories(42L, "health question");
    }

    @Test
    void pendingImmediateAndFailedActionsReturnStructuredReplies() {
        authenticate(42L);
        Fixtures f = fixtures();
        when(f.conversations.insert(any(AgentConversation.class))).thenAnswer(invocation -> {
            invocation.<AgentConversation>getArgument(0).setId(20L);
            return 1;
        });
        AgentActionRequest pending = new AgentActionRequest(
                AgentActionType.RECORD_HEALTH_DATA, "record", "120/80", true, Map.of()
        );
        when(f.parser.parse("record")).thenReturn(Optional.of(pending));
        when(f.actions.createPendingAction(any(), any(), any(), any(), any())).thenReturn(
                AgentActionVO.pending("a1", AgentActionType.RECORD_HEALTH_DATA, "record", "120/80", true, Map.of())
        );
        var first = f.service.chat(new AgentChatDTO(null, "record"));
        assertThat(first.pendingAction()).isNotNull();

        AgentActionRequest immediate = new AgentActionRequest(
                AgentActionType.EVALUATE_HEALTH_RISK, "risk", "risk", false, Map.of()
        );
        when(f.parser.parse("risk")).thenReturn(Optional.of(immediate));
        when(f.actions.executeImmediate(any(), any(), any(), any(), any())).thenReturn(
                AgentActionVO.result("a2", AgentActionType.EVALUATE_HEALTH_RISK,
                        AgentActionStatus.EXECUTED, Map.of(), null,
                        Map.of("risk", Map.of("summary", "stable", "riskScore", 12, "riskLevel", "normal")))
        );
        assertThat(f.service.chat(new AgentChatDTO(null, "risk")).answer()).isNotBlank();

        when(f.parser.parse("failure")).thenReturn(Optional.of(immediate));
        when(f.actions.executeImmediate(any(), any(), any(), any(), any()))
                .thenThrow(new IllegalArgumentException(""));
        assertThat(f.service.chat(new AgentChatDTO(null, "failure")).answer()).isNotBlank();
    }

    @Test
    void privateFormattingDecisionAndErrorHelpersCoverBoundaryBranches() throws Exception {
        Fixtures f = fixtures();
        for (AgentActionType type : AgentActionType.values()) {
            assertThat(invoke(f.service, "pendingActionAnswer",
                    new Class<?>[]{AgentActionType.class, String.class}, type, null)).isNotNull();
        }
        AgentActionVO hospitalWithResults = AgentActionVO.result(
                "h", AgentActionType.SEARCH_NEARBY_HOSPITALS, AgentActionStatus.EXECUTED,
                Map.of(), null, Map.of("nearbyHospitals", List.of(Map.of("name", "hospital")))
        );
        AgentActionVO hospitalEmpty = AgentActionVO.result(
                "h2", AgentActionType.SEARCH_NEARBY_HOSPITALS, AgentActionStatus.EXECUTED,
                Map.of(), "done", Map.of()
        );
        AgentActionVO generic = AgentActionVO.result(
                "g", AgentActionType.PREPARE_SOS_PLAN, AgentActionStatus.EXECUTED,
                Map.of(), null, null
        );
        AgentActionVO riskWithoutRiskMap = AgentActionVO.result(
                "r", AgentActionType.EVALUATE_HEALTH_RISK, AgentActionStatus.EXECUTED,
                Map.of(), "fallback result", Map.of()
        );
        AgentActionVO hospitalNullMessage = AgentActionVO.result(
                "h3", AgentActionType.SEARCH_NEARBY_HOSPITALS, AgentActionStatus.EXECUTED,
                Map.of(), null, Map.of("nearbyHospitals", List.of())
        );
        assertThat(invoke(f.service, "immediateActionAnswer",
                new Class<?>[]{AgentActionType.class, AgentActionVO.class},
                AgentActionType.SEARCH_NEARBY_HOSPITALS, hospitalWithResults)).isNotNull();
        assertThat(invoke(f.service, "immediateActionAnswer",
                new Class<?>[]{AgentActionType.class, AgentActionVO.class},
                AgentActionType.SEARCH_NEARBY_HOSPITALS, hospitalEmpty)).isNotNull();
        assertThat(invoke(f.service, "immediateActionAnswer",
                new Class<?>[]{AgentActionType.class, AgentActionVO.class},
                AgentActionType.PREPARE_SOS_PLAN, generic)).isNotNull();
        assertThat(invoke(f.service, "immediateActionAnswer",
                new Class<?>[]{AgentActionType.class, AgentActionVO.class},
                AgentActionType.EVALUATE_HEALTH_RISK, riskWithoutRiskMap)).isEqualTo("fallback result");
        assertThat(invoke(f.service, "immediateActionAnswer",
                new Class<?>[]{AgentActionType.class, AgentActionVO.class},
                AgentActionType.SEARCH_NEARBY_HOSPITALS, hospitalNullMessage)).isNotNull();

        for (AgentActionType type : AgentActionType.values()) {
            assertThat(invoke(f.service, "actionPreparationFailureAnswer",
                    new Class<?>[]{AgentActionType.class, RuntimeException.class},
                    type, new IllegalStateException(type.ordinal() % 2 == 0 ? null : "failed"))).isNotNull();
        }
        for (String role : List.of("PATIENT", "CAREGIVER")) {
            for (String text : List.of("血压", "血糖", "服药提醒", "other")) {
                assertThat((List<?>) invoke(f.service, "buildSuggestions",
                        new Class<?>[]{String.class, String.class}, text, role)).isNotEmpty();
            }
        }
        assertThat(invoke(f.service, "buildTitle", new Class<?>[]{String.class},
                "a title that is definitely longer than eighteen characters")).isNotNull();
        assertThat(invoke(f.service, "safe", new Class<?>[]{Object.class}, new Object[]{null})).isNotNull();
        assertThat(invoke(f.service, "safe", new Class<?>[]{Object.class}, " ")).isNotNull();
        assertThat(invoke(f.service, "safe", new Class<?>[]{Object.class}, "value")).isEqualTo("value");
        assertThat(invoke(f.service, "safe", new Class<?>[]{Object.class, Object.class}, null, "fallback"))
                .isEqualTo("fallback");
        assertThat(invoke(f.service, "safe", new Class<?>[]{Object.class, Object.class}, "primary", "fallback"))
                .isEqualTo("primary");
        assertThat(invoke(f.service, "safeCitation", new Class<?>[]{Object.class}, new Object[]{null}))
                .isEqualTo("");
        assertThat(invoke(f.service, "safeCitation", new Class<?>[]{Object.class}, "citation"))
                .isEqualTo("citation");
        assertThat(invoke(f.service, "safeList", new Class<?>[]{List.class}, new Object[]{null})).isNotNull();
        assertThat(invoke(f.service, "safeList", new Class<?>[]{List.class}, List.of())).isNotNull();
        assertThat(invoke(f.service, "safeList", new Class<?>[]{List.class}, List.of("x"))).asString().contains("x");
        assertThat(invoke(f.service, "withUnit", new Class<?>[]{Object.class, String.class}, null, "kg")).isNotNull();
        assertThat(invoke(f.service, "withUnit", new Class<?>[]{Object.class, String.class}, 10, "kg"))
                .isEqualTo("10kg");
        assertThat(invoke(f.service, "enabledText", new Class<?>[]{Boolean.class}, true)).isNotNull();
        assertThat(invoke(f.service, "enabledText", new Class<?>[]{Boolean.class}, false)).isNotNull();
        for (String type : List.of("blood_pressure", "blood_glucose", "heart_rate", "weight", "other")) {
            assertThat(invoke(f.service, "typeName", new Class<?>[]{String.class}, type)).isNotNull();
        }
        assertThat(invoke(f.service, "typeName", new Class<?>[]{String.class}, new Object[]{null})).isNotNull();

        assertThat(invoke(f.service, "extractHttpStatus", new Class<?>[]{Throwable.class},
                new RuntimeException("code 429", new RuntimeException("status 500")))).isEqualTo("429");
        assertThat(invoke(f.service, "extractHttpStatus", new Class<?>[]{Throwable.class},
                new StatusException())).isEqualTo("418");
        assertThat(invoke(f.service, "extractHttpStatus", new Class<?>[]{Throwable.class},
                new RuntimeException())).isEqualTo("unknown");
        assertThat(invoke(f.service, "summarizeThrowable", new Class<?>[]{Throwable.class},
                new RuntimeException())).isNotNull();
        assertThat(invoke(f.service, "summarizeThrowable", new Class<?>[]{Throwable.class},
                new RuntimeException("outer", new IllegalStateException("inner"))))
                .asString().contains("outer", "caused by", "inner");
        assertThat(invoke(f.service, "summarizeThrowable", new Class<?>[]{Throwable.class},
                new RuntimeException("x".repeat(600)))).asString().endsWith("...");
    }

    private Fixtures fixtures() {
        AgentConversationMapper conversations = mock(AgentConversationMapper.class);
        AgentMessageMapper messages = mock(AgentMessageMapper.class);
        AgentMemoryMapper memories = mock(AgentMemoryMapper.class);
        AgentLlmClient llm = mock(AgentLlmClient.class);
        AgentToolExecutor tools = mock(AgentToolExecutor.class);
        UserService users = mock(UserService.class);
        HealthService health = mock(HealthService.class);
        ReminderService reminders = mock(ReminderService.class);
        AgentIntentParser parser = mock(AgentIntentParser.class);
        AgentActionService actions = mock(AgentActionService.class);
        GmsMemoryClient gms = mock(GmsMemoryClient.class);
        AtomicLong ids = new AtomicLong(100);
        when(messages.insert(any(AgentMessage.class))).thenAnswer(invocation -> {
            invocation.<AgentMessage>getArgument(0).setId(ids.incrementAndGet());
            return 1;
        });
        when(llm.chat(any(), any())).thenReturn("answer");
        when(gms.searchMemories(any(), any())).thenReturn(List.of());
        when(parser.parse(any())).thenReturn(Optional.empty());
        AgentService service = new AgentService(
                conversations, messages, llm, tools,
                new AgentToolDecisionService(), new AgentPromptBuilder(),
                new AgentMemoryService(memories), new AgentSafetyService(),
                new AgentAnswerFormatter(), users, health, reminders, parser, actions, gms
        );
        return new Fixtures(service, conversations, messages, llm, parser, actions, gms);
    }

    private AgentConversation conversation(Long id, Long actor, Long target, String role) {
        AgentConversation result = new AgentConversation();
        result.setId(id);
        result.setUserId(actor);
        result.setTargetUserId(target);
        result.setActorRole(role);
        result.setStatus("active");
        return result;
    }

    private Object invoke(Object target, String name, Class<?>[] types, Object... args) throws Exception {
        Method method = target.getClass().getDeclaredMethod(name, types);
        method.setAccessible(true);
        return method.invoke(target, args);
    }

    private void authenticate(Long id) {
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(
                        new JwtService.JwtUser(id, "agent-full-test"), null, List.of())
        );
    }

    private record Fixtures(
            AgentService service,
            AgentConversationMapper conversations,
            AgentMessageMapper messages,
            AgentLlmClient llm,
            AgentIntentParser parser,
            AgentActionService actions,
            GmsMemoryClient gms
    ) {
    }

    public static final class StatusException extends RuntimeException {
        public int getStatusCode() {
            return 418;
        }
    }
}

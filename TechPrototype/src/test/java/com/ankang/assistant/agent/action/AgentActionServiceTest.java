package com.ankang.assistant.agent.action;

import com.ankang.assistant.agent.tool.AgentToolExecutor;
import com.ankang.assistant.config.JwtService;
import com.ankang.assistant.family.service.FamilyPermissionService;
import com.baomidou.mybatisplus.core.MybatisConfiguration;
import com.baomidou.mybatisplus.core.metadata.TableInfoHelper;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.ibatis.builder.MapperBuilderAssistant;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicReference;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class AgentActionServiceTest {

    @BeforeAll
    static void initTableInfo() {
        TableInfoHelper.initTableInfo(new MapperBuilderAssistant(new MybatisConfiguration(), ""), AgentAction.class);
    }

    @AfterEach
    void clearSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void createsPendingAction() {
        AgentActionMapper mapper = mock(AgentActionMapper.class);
        AtomicReference<AgentAction> stored = new AtomicReference<>();
        when(mapper.insert(any(AgentAction.class))).thenAnswer(invocation -> {
            AgentAction action = invocation.getArgument(0);
            action.setId(1L);
            stored.set(action);
            return 1;
        });
        AgentActionService service = service(mapper, mock(AgentToolExecutor.class));

        AgentActionVO result = service.createPendingAction(
                42L, 42L, "PATIENT", 7L,
                recordRequest()
        );

        assertThat(result.actionId()).startsWith("act_");
        assertThat(result.status()).isEqualTo("PENDING_CONFIRMATION");
        assertThat(stored.get().getStatus()).isEqualTo("PENDING_CONFIRMATION");
    }

    @Test
    void confirmExecutesTool() {
        authenticateAs(42L);
        AgentActionMapper mapper = mock(AgentActionMapper.class);
        AtomicReference<AgentAction> stored = new AtomicReference<>(pendingAction());
        AgentToolExecutor executor = mock(AgentToolExecutor.class);
        when(mapper.selectOne(any())).thenAnswer(invocation -> stored.get());
        when(mapper.updateById(any(AgentAction.class))).thenAnswer(invocation -> {
            stored.set(invocation.getArgument(0));
            return 1;
        });
        when(executor.executeAction(any(), any(), any()))
                .thenReturn(AgentActionResult.success("健康数据已成功记录。", Map.of("saved", true)));

        AgentActionVO result = service(mapper, executor)
                .confirm(new AgentActionConfirmRequest("act_test", true));

        assertThat(result.status()).isEqualTo("EXECUTED");
        assertThat(result.resultMessage()).isEqualTo("健康数据已成功记录。");
        verify(executor).executeAction(any(), any(), any());
    }

    @Test
    void cancelDoesNotExecuteTool() {
        authenticateAs(42L);
        AgentActionMapper mapper = mock(AgentActionMapper.class);
        AgentToolExecutor executor = mock(AgentToolExecutor.class);
        when(mapper.selectOne(any())).thenReturn(pendingAction());

        AgentActionVO result = service(mapper, executor)
                .confirm(new AgentActionConfirmRequest("act_test", false));

        assertThat(result.status()).isEqualTo("CANCELLED");
        verify(executor, never()).executeAction(any(), any(), any());
    }

    @Test
    void expiredActionCannotExecute() {
        authenticateAs(42L);
        AgentAction expired = pendingAction();
        expired.setExpiresAt(LocalDateTime.now().minusSeconds(1));
        AgentActionMapper mapper = mock(AgentActionMapper.class);
        AgentToolExecutor executor = mock(AgentToolExecutor.class);
        when(mapper.selectOne(any())).thenReturn(expired);

        AgentActionVO result = service(mapper, executor)
                .confirm(new AgentActionConfirmRequest("act_test", true));

        assertThat(result.status()).isEqualTo("EXPIRED");
        verify(executor, never()).executeAction(any(), any(), any());
    }

    @Test
    void immediateExecutionCoversSuccessFailureAndThrownException() {
        AgentActionMapper mapper = mock(AgentActionMapper.class);
        when(mapper.insert(any(AgentAction.class))).thenReturn(1);
        AgentToolExecutor executor = mock(AgentToolExecutor.class);
        when(executor.executeAction(any(), any(), any())).thenReturn(
                AgentActionResult.failure("rejected"),
                AgentActionResult.success("done", Map.of("saved", true))
        ).thenThrow(new IllegalStateException("x".repeat(200)));
        AgentActionService service = service(mapper, executor);

        AgentActionVO failed = service.executeImmediate(
                42L, null, null, null, recordRequest()
        );
        assertThat(failed.status()).isEqualTo("FAILED");
        AgentActionVO done = service.executeImmediate(
                42L, 42L, "PATIENT", null, recordRequest()
        );
        assertThat(done.status()).isEqualTo("EXECUTED");
        AgentActionVO thrown = service.executeImmediate(
                42L, 42L, "PATIENT", null, recordRequest()
        );
        assertThat(thrown.status()).isEqualTo("FAILED");
        assertThat(thrown.resultMessage()).hasSizeLessThan(210);
    }

    @Test
    void confirmRejectsMissingAndReturnsEveryTerminalStatusIdempotently() {
        authenticateAs(42L);
        AgentActionMapper mapper = mock(AgentActionMapper.class);
        AgentActionService service = service(mapper, mock(AgentToolExecutor.class));
        when(mapper.selectOne(any())).thenReturn(null);
        assertThatThrownBy(() -> service.confirm(new AgentActionConfirmRequest("missing", true)))
                .isInstanceOf(IllegalArgumentException.class);

        for (AgentActionStatus status : List.of(
                AgentActionStatus.EXECUTED, AgentActionStatus.CANCELLED,
                AgentActionStatus.EXPIRED, AgentActionStatus.FAILED
        )) {
            AgentAction action = pendingAction();
            action.setStatus(status.name());
            action.setResult("{bad json");
            action.setErrorMessage(status == AgentActionStatus.FAILED ? null : "error");
            when(mapper.selectOne(any())).thenReturn(action);
            assertThat(service.confirm(new AgentActionConfirmRequest("act_test", true)).status())
                    .isEqualTo(status.name());
            if (status == AgentActionStatus.FAILED) {
                action.setErrorMessage("specific");
                assertThat(service.confirm(new AgentActionConfirmRequest("act_test", true)).resultMessage())
                        .contains("specific");
            }
        }
    }

    @Test
    void actionPermissionsCoverPatientAndCaregiverRejectionsAndGrant() {
        AgentActionMapper mapper = mock(AgentActionMapper.class);
        FamilyPermissionService permission = mock(FamilyPermissionService.class);
        AgentActionService service = new AgentActionService(
                mapper, mock(AgentToolExecutor.class), new AgentActionValidator(),
                new ObjectMapper(), permission
        );
        assertThatThrownBy(() -> service.createPendingAction(
                null, 2L, "PATIENT", null, recordRequest()
        )).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> service.createPendingAction(
                1L, 2L, "PATIENT", null, recordRequest()
        )).isInstanceOf(IllegalArgumentException.class);
        when(permission.hasCaregiverAccess(any(), any(), any())).thenReturn(false, true);
        assertThatThrownBy(() -> service.createPendingAction(
                1L, 2L, "CAREGIVER", null,
                new AgentActionRequest(AgentActionType.EVALUATE_HEALTH_RISK, "risk", "risk", true, Map.of())
        )).isInstanceOf(IllegalArgumentException.class);
        service.createPendingAction(
                1L, 2L, "CAREGIVER", null,
                new AgentActionRequest(AgentActionType.EVALUATE_HEALTH_RISK, "risk", "risk", true, Map.of())
        );
        verify(mapper).insert(any(AgentAction.class));
    }

    @Test
    void serializationFallbacksSafeMessagesAndPendingStatusAreCovered() throws Exception {
        AgentActionService service = service(
                mock(AgentActionMapper.class), mock(AgentToolExecutor.class));

        assertThat((Map<?, ?>) ReflectionTestUtils.invokeMethod(
                service, "readPayload", new Object[]{null})).isEmpty();
        assertThat((Map<?, ?>) ReflectionTestUtils.invokeMethod(
                service, "readPayload", " ")).isEmpty();
        assertThat((Map<?, ?>) ReflectionTestUtils.invokeMethod(
                service, "readPayload", "{bad")).isEmpty();
        Map<?, ?> validPayload = ReflectionTestUtils.invokeMethod(
                service, "readPayload", "{\"a\":1}");
        assertThat(validPayload).hasSize(1);
        assertThat(validPayload.get("a")).isEqualTo(1);
        assertThat((String) ReflectionTestUtils.invokeMethod(
                service, "writeJson", new Object[]{null})).isEqualTo("{}");

        assertThat((String) ReflectionTestUtils.invokeMethod(
                service, "safeMessage", new RuntimeException())).isEqualTo("RuntimeException");
        assertThat((String) ReflectionTestUtils.invokeMethod(
                service, "safeMessage", new RuntimeException(" "))).isEqualTo("RuntimeException");
        assertThat((String) ReflectionTestUtils.invokeMethod(
                service, "safeMessage", new RuntimeException("short"))).isEqualTo("short");
        assertThat((String) ReflectionTestUtils.invokeMethod(
                service, "safeMessage", new RuntimeException("x".repeat(181)))).hasSize(180);

        AgentAction action = pendingAction();
        assertThat((String) ReflectionTestUtils.invokeMethod(
                service, "statusMessage", AgentActionStatus.PENDING_CONFIRMATION, action))
                .isEqualTo("等待确认");

        ObjectMapper brokenMapper = mock(ObjectMapper.class);
        when(brokenMapper.writeValueAsString(any())).thenThrow(
                new com.fasterxml.jackson.core.JsonProcessingException("broken") { });
        AgentActionService broken = new AgentActionService(
                mock(AgentActionMapper.class), mock(AgentToolExecutor.class),
                new AgentActionValidator(), brokenMapper, mock(FamilyPermissionService.class));
        assertThatThrownBy(() -> ReflectionTestUtils.invokeMethod(
                broken, "writeJson", Map.of("a", 1)))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("序列化失败");
    }

    @Test
    void blankRoleAndExplicitTargetBuildExpectedActionDefaults() {
        AgentActionMapper mapper = mock(AgentActionMapper.class);
        AtomicReference<AgentAction> inserted = new AtomicReference<>();
        when(mapper.insert(any(AgentAction.class))).thenAnswer(invocation -> {
            inserted.set(invocation.getArgument(0));
            return 1;
        });
        AgentActionService service = service(mapper, mock(AgentToolExecutor.class));

        service.createPendingAction(42L, null, " ", null, recordRequest());
        assertThat(inserted.get().getTargetUserId()).isEqualTo(42L);
        assertThat(inserted.get().getActorRole()).isEqualTo("PATIENT");

        service.createPendingAction(42L, 42L, "PATIENT", 9L, recordRequest());
        assertThat(inserted.get().getTargetUserId()).isEqualTo(42L);
        assertThat(inserted.get().getActorRole()).isEqualTo("PATIENT");
        assertThat(inserted.get().getSessionId()).isEqualTo(9L);
    }

    private AgentActionService service(AgentActionMapper mapper, AgentToolExecutor executor) {
        return new AgentActionService(
                mapper,
                executor,
                new AgentActionValidator(),
                new ObjectMapper(),
                mock(FamilyPermissionService.class)
        );
    }

    private AgentActionRequest recordRequest() {
        return new AgentActionRequest(
                AgentActionType.RECORD_HEALTH_DATA,
                "确认录入健康数据",
                "血压 160/100",
                true,
                Map.of("systolic", 160, "diastolic", 100)
        );
    }

    private AgentAction pendingAction() {
        AgentAction action = new AgentAction();
        action.setActionId("act_test");
        action.setUserId(42L);
        action.setTargetUserId(42L);
        action.setActorRole("PATIENT");
        action.setSessionId(7L);
        action.setActionType(AgentActionType.RECORD_HEALTH_DATA.name());
        action.setStatus(AgentActionStatus.PENDING_CONFIRMATION.name());
        action.setPayload("{\"systolic\":160,\"diastolic\":100}");
        action.setExpiresAt(LocalDateTime.now().plusMinutes(5));
        return action;
    }

    private void authenticateAs(Long userId) {
        JwtService.JwtUser principal = new JwtService.JwtUser(userId, "agent-action-test");
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(principal, null, List.of())
        );
    }
}

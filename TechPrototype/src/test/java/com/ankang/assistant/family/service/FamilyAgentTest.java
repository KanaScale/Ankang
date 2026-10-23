package com.ankang.assistant.family.service;

import com.ankang.assistant.agent.dto.AgentChatDTO;
import com.ankang.assistant.agent.entity.AgentConversation;
import com.ankang.assistant.agent.entity.AgentMemory;
import com.ankang.assistant.agent.entity.AgentMessage;
import com.ankang.assistant.agent.llm.AgentChatTurn;
import com.ankang.assistant.agent.llm.AgentLlmClient;
import com.ankang.assistant.agent.action.AgentActionService;
import com.ankang.assistant.agent.action.AgentIntentParser;
import com.ankang.assistant.agent.mapper.AgentConversationMapper;
import com.ankang.assistant.agent.mapper.AgentMemoryMapper;
import com.ankang.assistant.agent.mapper.AgentMessageMapper;
import com.ankang.assistant.agent.gms.GmsMemoryClient;
import com.ankang.assistant.agent.service.AgentAnswerFormatter;
import com.ankang.assistant.agent.service.AgentMemoryService;
import com.ankang.assistant.agent.service.AgentPromptBuilder;
import com.ankang.assistant.agent.service.AgentSafetyService;
import com.ankang.assistant.agent.service.AgentService;
import com.ankang.assistant.agent.service.AgentToolDecisionService;
import com.ankang.assistant.agent.tool.AgentToolExecutor;
import com.ankang.assistant.health.service.HealthService;
import com.ankang.assistant.health.vo.HealthRecordVO;
import com.ankang.assistant.health.vo.HealthSummaryVO;
import com.ankang.assistant.reminder.service.ReminderService;
import com.ankang.assistant.user.service.UserService;
import com.ankang.assistant.user.vo.HealthGoalVO;
import com.ankang.assistant.user.vo.HealthProfileVO;
import com.ankang.assistant.user.vo.UserProfileVO;
import com.ankang.assistant.user.vo.UserSettingVO;
import com.baomidou.mybatisplus.core.MybatisConfiguration;
import com.baomidou.mybatisplus.core.metadata.TableInfoHelper;
import org.apache.ibatis.builder.MapperBuilderAssistant;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.transaction.UnexpectedRollbackException;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class FamilyAgentTest {

    @BeforeAll
    static void initMybatisPlusTableInfo() {
        MybatisConfiguration configuration = new MybatisConfiguration();
        TableInfoHelper.initTableInfo(new MapperBuilderAssistant(configuration, ""), AgentConversation.class);
        TableInfoHelper.initTableInfo(new MapperBuilderAssistant(configuration, ""), AgentMessage.class);
        TableInfoHelper.initTableInfo(new MapperBuilderAssistant(configuration, ""), AgentMemory.class);
    }

    @Test
    void caregiverChatUsesPatientHealthContextAndCaregiverConversation() {
        AgentConversationMapper conversationMapper = mock(AgentConversationMapper.class);
        AgentMessageMapper messageMapper = mock(AgentMessageMapper.class);
        AgentMemoryMapper memoryMapper = mock(AgentMemoryMapper.class);
        AgentToolExecutor toolExecutor = mock(AgentToolExecutor.class);
        UserService userService = mock(UserService.class);
        HealthService healthService = mock(HealthService.class);
        ReminderService reminderService = mock(ReminderService.class);
        CapturingLlmClient llmClient = new CapturingLlmClient();

        when(conversationMapper.insert(any(AgentConversation.class))).thenAnswer(invocation -> {
            AgentConversation conversation = invocation.getArgument(0);
            conversation.setId(30L);
            return 1;
        });
        when(messageMapper.insert(any(AgentMessage.class))).thenAnswer(invocation -> {
            AgentMessage message = invocation.getArgument(0);
            message.setId(message.getRole().equals("user") ? 301L : 302L);
            return 1;
        });
        AgentMessage recentUserMessage = new AgentMessage();
        recentUserMessage.setRole("user");
        recentUserMessage.setContent("我爸爸最近血压怎么样？");
        when(messageMapper.selectList(any())).thenReturn(List.of(recentUserMessage));
        when(userService.getProfileByUserId(1L)).thenReturn(new UserProfileVO(
                1L, "patient", "张三", 72, "男", null, null, null, "PATIENT"
        ));
        when(userService.getHealthProfileByUserId(1L)).thenReturn(new HealthProfileVO(
                new BigDecimal("170"),
                new BigDecimal("70"),
                new BigDecimal("24.2"),
                List.of("高血压"),
                null,
                null,
                null
        ));
        when(userService.getHealthGoalByUserId(1L)).thenReturn(new HealthGoalVO(
                "6000", null, "7", null, "140/90", null
        ));
        when(userService.getSettingsByUserId(1L)).thenReturn(new UserSettingVO(
                new BigDecimal("1.00"), true, false, false
        ));
        when(healthService.getSummaryByUserId(1L)).thenReturn(new HealthSummaryVO(
                75,
                "部分指标偏离正常范围",
                List.of(new HealthSummaryVO.MetricVO(
                        "blood_pressure", "血压", "150/92", "mmHg", "warning", "+6"
                ))
        ));
        when(healthService.listRecentRecordsByUserId(1L, 5)).thenReturn(List.of(new HealthRecordVO(
                22L,
                "blood_pressure",
                new BigDecimal("150"),
                new BigDecimal("150"),
                new BigDecimal("92"),
                150,
                92,
                "mmHg",
                "warning",
                "manual",
                null,
                LocalDateTime.of(2026, 7, 24, 8, 0)
        )));
        when(reminderService.listPendingRemindersByUserId(1L, 5)).thenReturn(List.of());

        AgentService service = new AgentService(
                conversationMapper,
                messageMapper,
                llmClient,
                toolExecutor,
                new AgentToolDecisionService(),
                new AgentPromptBuilder(),
                new AgentMemoryService(memoryMapper),
                new AgentSafetyService(),
                new AgentAnswerFormatter(),
                userService,
                healthService,
                reminderService
        );

        var reply = service.chatForCaregiver(7L, 1L, new AgentChatDTO(null, "我爸爸最近血压怎么样？"));

        ArgumentCaptor<AgentConversation> conversationCaptor = ArgumentCaptor.forClass(AgentConversation.class);
        verify(conversationMapper).insert(conversationCaptor.capture());
        assertThat(conversationCaptor.getValue().getUserId()).isEqualTo(7L);
        assertThat(conversationCaptor.getValue().getTargetUserId()).isEqualTo(1L);
        assertThat(conversationCaptor.getValue().getActorRole()).isEqualTo("CAREGIVER");
        assertThat(llmClient.systemPrompt).contains(
                "当前提问者是家属/照护者",
                "被照护者",
                "昵称 张三",
                "高血压",
                "血压 150/92mmHg"
        );
        assertThat(reply.answer()).startsWith("照护者视角");
        verify(memoryMapper, never()).insert(any(AgentMemory.class));
    }

    @Test
    void caregiverAgentDoesNotExposeRollbackOnlyActionFailure() {
        AgentConversationMapper conversationMapper = mock(AgentConversationMapper.class);
        AgentMessageMapper messageMapper = mock(AgentMessageMapper.class);
        AgentMemoryMapper memoryMapper = mock(AgentMemoryMapper.class);
        AgentActionService actionService = mock(AgentActionService.class);

        when(conversationMapper.insert(any(AgentConversation.class))).thenAnswer(invocation -> {
            AgentConversation conversation = invocation.getArgument(0);
            conversation.setId(31L);
            return 1;
        });
        when(messageMapper.insert(any(AgentMessage.class))).thenAnswer(invocation -> {
            AgentMessage message = invocation.getArgument(0);
            message.setId(message.getRole().equals("user") ? 311L : 312L);
            return 1;
        });
        when(actionService.executeImmediate(any(), any(), any(), any(), any()))
                .thenThrow(new UnexpectedRollbackException(
                        "Transaction rolled back because it has been marked as rollback-only"
                ));

        AgentService service = new AgentService(
                conversationMapper,
                messageMapper,
                new CapturingLlmClient(),
                mock(AgentToolExecutor.class),
                new AgentToolDecisionService(),
                new AgentPromptBuilder(),
                new AgentMemoryService(memoryMapper),
                new AgentSafetyService(),
                new AgentAnswerFormatter(),
                mock(UserService.class),
                mock(HealthService.class),
                mock(ReminderService.class),
                new AgentIntentParser(),
                actionService,
                GmsMemoryClient.disabled()
        );

        var reply = service.chatForCaregiver(7L, 1L, new AgentChatDTO(null, "请评估一下风险"));

        assertThat(reply.answer()).startsWith("照护者视角");
        assertThat(reply.answer()).contains("暂时没有完成");
        assertThat(reply.answer()).doesNotContain("rollback-only", "Transaction rolled back");
    }

    private static final class CapturingLlmClient implements AgentLlmClient {
        private String systemPrompt;

        @Override
        public String chat(String systemPrompt, List<AgentChatTurn> turns) {
            this.systemPrompt = systemPrompt;
            return "从近期记录看，血压需要继续观察。";
        }

        @Override
        public boolean realModel() {
            return false;
        }
    }
}

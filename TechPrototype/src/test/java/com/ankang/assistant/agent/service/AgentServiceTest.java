package com.ankang.assistant.agent.service;

import com.ankang.assistant.agent.dto.AgentChatDTO;
import com.ankang.assistant.agent.entity.AgentConversation;
import com.ankang.assistant.agent.entity.AgentMemory;
import com.ankang.assistant.agent.entity.AgentMessage;
import com.ankang.assistant.agent.llm.AgentChatTurn;
import com.ankang.assistant.agent.llm.AgentLlmClient;
import com.ankang.assistant.agent.llm.MockAgentLlmClient;
import com.ankang.assistant.agent.mapper.AgentConversationMapper;
import com.ankang.assistant.agent.mapper.AgentMemoryMapper;
import com.ankang.assistant.agent.mapper.AgentMessageMapper;
import com.ankang.assistant.agent.tool.AgentToolExecutor;
import com.ankang.assistant.agent.tool.WebSearchResult;
import com.ankang.assistant.agent.vo.AgentReplyVO;
import com.ankang.assistant.config.JwtService;
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
import com.baomidou.mybatisplus.core.MybatisConfiguration;
import com.baomidou.mybatisplus.core.metadata.TableInfoHelper;
import org.apache.ibatis.builder.MapperBuilderAssistant;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.concurrent.atomic.AtomicLong;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class AgentServiceTest {

    @BeforeAll
    static void initMybatisPlusTableInfo() {
        MybatisConfiguration configuration = new MybatisConfiguration();
        TableInfoHelper.initTableInfo(new MapperBuilderAssistant(configuration, ""), AgentConversation.class);
        TableInfoHelper.initTableInfo(new MapperBuilderAssistant(configuration, ""), AgentMessage.class);
        TableInfoHelper.initTableInfo(new MapperBuilderAssistant(configuration, ""), AgentMemory.class);
    }

    @AfterEach
    void clearSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void chatCreatesConversationSavesMessagesAndReturnsCitations() {
        authenticateAs(42L);
        AgentConversationMapper conversationMapper = mock(AgentConversationMapper.class);
        AgentMessageMapper messageMapper = mock(AgentMessageMapper.class);
        AgentMemoryMapper memoryMapper = mock(AgentMemoryMapper.class);
        AgentToolExecutor toolExecutor = mock(AgentToolExecutor.class);
        AtomicLong messageIds = new AtomicLong(100L);

        when(conversationMapper.insert(any(AgentConversation.class))).thenAnswer(invocation -> {
            AgentConversation conversation = invocation.getArgument(0);
            conversation.setId(10L);
            return 1;
        });
        when(messageMapper.insert(any(AgentMessage.class))).thenAnswer(invocation -> {
            AgentMessage message = invocation.getArgument(0);
            message.setId(messageIds.incrementAndGet());
            return 1;
        });
        AgentMessage recentUserMessage = new AgentMessage();
        recentUserMessage.setRole("user");
        recentUserMessage.setContent("最新高血压指南怎么说？");
        when(messageMapper.selectList(any())).thenReturn(List.of(recentUserMessage));
        when(memoryMapper.selectList(any())).thenReturn(List.of());
        when(toolExecutor.webSearch(any())).thenReturn(List.of(new WebSearchResult(
                "高血压健康管理科普",
                "https://example.com/health/hypertension-guide",
                "高血压管理应结合家庭血压监测和医生建议。",
                "web_search"
        )));

        AgentService service = new AgentService(
                conversationMapper,
                messageMapper,
                new MockAgentLlmClient(),
                toolExecutor,
                new AgentToolDecisionService(),
                new AgentPromptBuilder(),
                new AgentMemoryService(memoryMapper),
                new AgentSafetyService(),
                new AgentAnswerFormatter(),
                mock(UserService.class),
                mock(HealthService.class),
                mock(ReminderService.class)
        );

        AgentReplyVO reply = service.chat(new AgentChatDTO(null, "最新高血压指南怎么说？"));

        assertThat(reply.sessionId()).isEqualTo(10L);
        assertThat(reply.messageId()).isNotNull();
        assertThat(reply.answer()).isNotBlank();
        assertThat(reply.citations()).hasSize(1);
        assertThat(reply.citations().get(0).source()).isEqualTo("web_search");
        verify(conversationMapper).insert(any(AgentConversation.class));
        verify(messageMapper, times(2)).insert(any(AgentMessage.class));
    }

    @Test
    void chatPromptIncludesFreshStructuredUserContext() {
        authenticateAs(42L);
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
            conversation.setId(20L);
            return 1;
        });
        when(messageMapper.insert(any(AgentMessage.class))).thenAnswer(invocation -> {
            AgentMessage message = invocation.getArgument(0);
            message.setId(200L);
            return 1;
        });
        AgentMessage recentUserMessage = new AgentMessage();
        recentUserMessage.setRole("user");
        recentUserMessage.setContent("我的个人资料现在是什么？");
        when(messageMapper.selectList(any())).thenReturn(List.of(recentUserMessage));
        AgentMemory staleMemory = new AgentMemory();
        staleMemory.setMemoryValue("我以前说过我是男性");
        when(memoryMapper.selectList(any())).thenReturn(List.of(staleMemory));
        when(userService.getProfile()).thenReturn(new UserProfileVO(
                42L,
                "tester",
                "李阿姨",
                68,
                "女",
                "13800000000",
                "li@example.com",
                "https://example.com/avatar.png",
                "PATIENT"
        ));
        when(userService.getProfileByUserId(42L)).thenReturn(new UserProfileVO(
                42L,
                "tester",
                "李阿姨",
                68,
                "女",
                "13800000000",
                "li@example.com",
                "https://example.com/avatar.png",
                "PATIENT"
        ));
        when(userService.getHealthProfileByUserId(42L)).thenReturn(new HealthProfileVO(
                new BigDecimal("160.0"),
                new BigDecimal("61.0"),
                new BigDecimal("23.8"),
                List.of("糖尿病"),
                "青霉素",
                "2024 年做过白内障手术",
                "安康手环"
        ));
        when(userService.getHealthGoalByUserId(42L)).thenReturn(new HealthGoalVO(
                "6000 步",
                "膝盖不舒服时减量",
                "7 小时",
                "午休不超过 30 分钟",
                "< 130/80 mmHg",
                "早晚各测一次"
        ));
        when(userService.getSettingsByUserId(42L)).thenReturn(new UserSettingVO(
                new BigDecimal("1.20"),
                true,
                true,
                false
        ));
        when(healthService.getSummaryByUserId(42L)).thenReturn(new HealthSummaryVO(
                90,
                "部分指标偏离正常范围",
                List.of(new HealthSummaryVO.MetricVO("blood_glucose", "血糖", "8.2", "mmol/L", "warning", "-0.2"))
        ));
        when(healthService.listRecentRecordsByUserId(any(Long.class), any(Integer.class))).thenReturn(List.of(new HealthRecordVO(
                6L,
                "blood_glucose",
                new BigDecimal("8.2"),
                new BigDecimal("8.2"),
                null,
                null,
                null,
                "mmol/L",
                "warning",
                "manual",
                "",
                LocalDateTime.of(2026, 7, 23, 14, 22)
        )));
        when(reminderService.listPendingRemindersByUserId(any(Long.class), any(Integer.class))).thenReturn(List.of(new ReminderVO(
                6L,
                null,
                "测血糖",
                "bloodSugar",
                null,
                null,
                LocalDateTime.of(2026, 7, 23, 13, 0),
                "13:00",
                "once",
                true,
                false
        )));

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

        service.chat(new AgentChatDTO(null, "我的个人资料现在是什么？"));

        assertThat(llmClient.systemPrompt).contains(
                "基础资料：",
                "昵称 李阿姨",
                "年龄 68",
                "性别 女",
                "手机号 13800000000",
                "邮箱 li@example.com",
                "BMI 23.8",
                "慢病 [糖尿病]",
                "过敏 青霉素",
                "病史 2024 年做过白内障手术",
                "设备 安康手环",
                "步数备注 膝盖不舒服时减量",
                "睡眠备注 午休不超过 30 分钟",
                "血压备注 早晚各测一次",
                "字体比例 1.20",
                "大触控 开启",
                "最新健康记录：[血糖 8.2mmol/L",
                "待办标题：测血糖",
                "如果长期记忆与用户上下文冲突"
        );
    }

    private void authenticateAs(Long userId) {
        JwtService.JwtUser principal = new JwtService.JwtUser(userId, "agent-test");
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(principal, null, List.of())
        );
    }

    private static final class CapturingLlmClient implements AgentLlmClient {
        private String systemPrompt;

        @Override
        public String chat(String systemPrompt, List<AgentChatTurn> turns) {
            this.systemPrompt = systemPrompt;
            return "已读取资料";
        }

        @Override
        public boolean realModel() {
            return false;
        }
    }
}

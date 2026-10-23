package com.ankang.assistant.agent.tool;

import com.ankang.assistant.agent.action.AgentActionExecutionContext;
import com.ankang.assistant.agent.action.AgentActionValidator;
import com.ankang.assistant.reminder.dto.ReminderSaveDTO;
import com.ankang.assistant.reminder.service.ReminderService;
import com.ankang.assistant.reminder.vo.ReminderVO;
import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.argThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.doThrow;

class CreateHealthPlanToolTest {

    @Test
    void concretePlanCreatesReminder() {
        ReminderService reminderService = mock(ReminderService.class);
        when(reminderService.createReminder(any(ReminderSaveDTO.class))).thenReturn(new ReminderVO(
                1L, null, "测血压", "bloodPressure", "", "", LocalDateTime.now(),
                "08:00", "daily", true, false
        ));
        CreateHealthPlanTool tool = new CreateHealthPlanTool(reminderService, new AgentActionValidator());

        var result = tool.executeAction(patientContext(), Map.of(
                "reminders", List.of(Map.of(
                        "title", "测血压",
                        "type", "bloodPressure",
                        "description", "按计划测量血压",
                        "remindTime", "08:00",
                        "repeatType", "daily"
                ))
        ));

        assertThat(result.success()).isTrue();
        assertThat(result.resultMessage()).contains("已创建 1 条提醒");
        verify(reminderService).createReminder(any(ReminderSaveDTO.class));
    }

    @Test
    void agentReminderUsesNextOccurrenceWhenTimeAlreadyPassedToday() {
        LocalDateTime now = LocalDateTime.of(2026, 7, 29, 21, 0);

        LocalDateTime remindAt = AgentToolPayloads.remindAt(Map.of(
                "remindTime", "08:00",
                "repeatType", "daily"
        ), now);

        assertThat(remindAt).isEqualTo(LocalDateTime.of(2026, 7, 30, 8, 0));
    }

    @Test
    void weeklyReminderUsesConfiguredWeekdayAndTime() {
        LocalDateTime now = LocalDateTime.of(2026, 7, 29, 21, 0);

        LocalDateTime remindAt = AgentToolPayloads.remindAt(Map.of(
                "remindTime", "09:30",
                "repeatType", "weekly",
                "dayOfWeek", 5
        ), now);

        assertThat(remindAt).isEqualTo(LocalDateTime.of(2026, 7, 31, 9, 30));
    }

    @Test
    void concretePlanPassesResolvedFutureRemindAtToReminderService() {
        ReminderService reminderService = mock(ReminderService.class);
        when(reminderService.createReminder(any(ReminderSaveDTO.class))).thenAnswer(invocation -> {
            ReminderSaveDTO dto = invocation.getArgument(0);
            return new ReminderVO(1L, dto.clientReminderId(), dto.title(), dto.type(),
                    dto.description(), dto.remark(), dto.remindAt(), dto.remindTime(),
                    dto.repeatType(), true, false);
        });
        CreateHealthPlanTool tool = new CreateHealthPlanTool(reminderService, new AgentActionValidator());

        tool.executeAction(patientContext(), Map.of(
                "reminders", List.of(Map.of(
                        "title", "服药提醒",
                        "type", "medicine",
                        "description", "按医嘱服药，不自行调整剂量",
                        "remindTime", LocalTime.now().minusHours(1).withSecond(0).withNano(0).toString(),
                        "repeatType", "daily"
                ))
        ));

        verify(reminderService).createReminder(argThat(dto -> dto.remindAt().isAfter(LocalDateTime.now())));
    }

    @Test
    void vaguePlanDoesNotCreateReminder() {
        ReminderService reminderService = mock(ReminderService.class);
        CreateHealthPlanTool tool = new CreateHealthPlanTool(reminderService, new AgentActionValidator());

        var result = tool.executeAction(patientContext(), Map.of(
                "reminders", List.of(),
                "suggestions", List.of("多运动")
        ));

        assertThat(result.success()).isTrue();
        assertThat(result.resultMessage()).contains("未直接创建提醒");
        verify(reminderService, never()).createReminder(any());
    }

    @Test
    void metadataAndCaregiverGuardAreCovered() {
        CreateHealthPlanTool tool = new CreateHealthPlanTool(
                mock(ReminderService.class), new AgentActionValidator());

        assertThat(tool.name()).isEqualTo("create_health_plan");
        assertThat(tool.description()).isNotBlank();
        assertThat(tool.execute(Map.of()).success()).isFalse();
        assertThat(tool.supportsAction(com.ankang.assistant.agent.action.AgentActionType.CREATE_HEALTH_PLAN))
                .isTrue();
        assertThat(tool.supportsAction(com.ankang.assistant.agent.action.AgentActionType.RECORD_HEALTH_DATA))
                .isFalse();

        AgentActionExecutionContext caregiver =
                new AgentActionExecutionContext("a", 7L, 42L, 1L, "CAREGIVER");
        assertThat(tool.executeAction(caregiver, Map.of()).success()).isFalse();
    }

    @Test
    void validationFailureNonMapBlankTimeAndDefaultFieldsAreCovered() {
        ReminderService reminders = mock(ReminderService.class);
        AgentActionValidator failingValidator = mock(AgentActionValidator.class);
        doThrow(new IllegalArgumentException("bad plan")).when(failingValidator)
                .validateForExecution(any(), any(), any());
        assertThat(new CreateHealthPlanTool(reminders, failingValidator)
                .executeAction(patientContext(), Map.of()).resultMessage()).contains("bad plan");

        AgentActionValidator permissive = mock(AgentActionValidator.class);
        CreateHealthPlanTool permissiveTool = new CreateHealthPlanTool(reminders, permissive);
        var skipped = permissiveTool.executeAction(patientContext(), Map.of(
                "reminders", List.of("not-a-map", Map.of("title", "无时间", "remindTime", ""))
        ));
        assertThat(skipped.success()).isTrue();
        verify(reminders, never()).createReminder(any());

        when(reminders.createReminder(any())).thenAnswer(invocation -> {
            ReminderSaveDTO dto = invocation.getArgument(0);
            return new ReminderVO(2L, null, dto.title(), dto.type(), dto.description(), dto.remark(),
                    dto.remindAt(), dto.remindTime(), dto.repeatType(), true, false);
        });
        var defaults = permissiveTool.executeAction(patientContext(), Map.of(
                "reminders", List.of(Map.of("title", "默认计划", "remindTime", "09:00"))
        ));
        assertThat(defaults.success()).isTrue();
        verify(reminders).createReminder(argThat(dto ->
                "other".equals(dto.type()) && "once".equals(dto.repeatType())));
    }

    private AgentActionExecutionContext patientContext() {
        return new AgentActionExecutionContext("act_plan", 42L, 42L, 7L, "PATIENT");
    }
}

package com.ankang.assistant.agent.tool;

import com.ankang.assistant.agent.action.AgentActionExecutionContext;
import com.ankang.assistant.agent.action.AgentActionResult;
import com.ankang.assistant.agent.action.AgentActionType;
import com.ankang.assistant.agent.action.AgentActionValidator;
import com.ankang.assistant.reminder.dto.ReminderSaveDTO;
import com.ankang.assistant.reminder.service.ReminderService;
import com.ankang.assistant.reminder.vo.ReminderVO;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Component
public class CreateHealthPlanTool implements AgentTool {

    private final ReminderService reminderService;
    private final AgentActionValidator validator;

    public CreateHealthPlanTool(ReminderService reminderService, AgentActionValidator validator) {
        this.reminderService = reminderService;
        this.validator = validator;
    }

    @Override
    public String name() {
        return "create_health_plan";
    }

    @Override
    public String description() {
        return "Create confirmed health plan reminders when the plan has clear schedule information.";
    }

    @Override
    public ToolCallResult execute(Map<String, String> arguments) {
        return ToolCallResult.failure(name(), "create_health_plan 只能通过 Agent Action 确认流程执行");
    }

    @Override
    public boolean supportsAction(AgentActionType actionType) {
        return actionType == AgentActionType.CREATE_HEALTH_PLAN;
    }

    @Override
    public AgentActionResult executeAction(AgentActionExecutionContext context, Map<String, Object> payload) {
        if (!context.patientActor()) {
            return AgentActionResult.failure("家属版 Agent 不能直接修改被照护者提醒");
        }
        try {
            validator.validateForExecution(AgentActionType.CREATE_HEALTH_PLAN, payload, context);
        } catch (RuntimeException ex) {
            return AgentActionResult.failure(ex.getMessage());
        }

        List<ReminderVO> created = new ArrayList<>();
        for (Object item : AgentToolPayloads.list(payload, "reminders")) {
            if (!(item instanceof Map<?, ?> reminder)) {
                continue;
            }
            String remindTime = AgentToolPayloads.string(reminder, "remindTime");
            if (remindTime.isBlank()) {
                continue;
            }
            created.add(reminderService.createReminder(new ReminderSaveDTO(
                    null,
                    AgentToolPayloads.string(reminder, "title"),
                    defaultString(AgentToolPayloads.string(reminder, "type"), "other"),
                    AgentToolPayloads.string(reminder, "description"),
                    AgentToolPayloads.string(reminder, "description"),
                    AgentToolPayloads.remindAt(reminder),
                    remindTime,
                    defaultString(AgentToolPayloads.string(reminder, "repeatType"), "once"),
                    true
            )));
        }

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("createdReminders", created);
        result.put("suggestions", AgentToolPayloads.list(payload, "suggestions"));
        if (created.isEmpty()) {
            return AgentActionResult.success("计划已整理为健康建议，因缺少明确时间，未直接创建提醒。", result);
        }
        return AgentActionResult.success("健康计划已创建 " + created.size() + " 条提醒。", result);
    }

    private String defaultString(String value, String fallback) {
        return value == null || value.isBlank() ? fallback : value;
    }
}

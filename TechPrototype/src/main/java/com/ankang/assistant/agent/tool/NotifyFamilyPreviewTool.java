package com.ankang.assistant.agent.tool;

import com.ankang.assistant.agent.action.AgentActionExecutionContext;
import com.ankang.assistant.agent.action.AgentActionResult;
import com.ankang.assistant.agent.action.AgentActionType;
import com.ankang.assistant.family.service.FamilyService;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Component
public class NotifyFamilyPreviewTool implements AgentTool {

    private static final DateTimeFormatter DATE_TIME_FORMATTER =
            DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    private final FamilyService familyService;

    public NotifyFamilyPreviewTool(FamilyService familyService) {
        this.familyService = familyService;
    }

    @Override
    public String name() {
        return "notify_family_preview";
    }

    @Override
    public String description() {
        return "Prepare a family notification preview without sending it.";
    }

    @Override
    public ToolCallResult execute(Map<String, String> arguments) {
        return ToolCallResult.failure(name(), "notify_family_preview 只能通过 Agent Action 确认流程执行");
    }

    @Override
    public boolean supportsAction(AgentActionType actionType) {
        return actionType == AgentActionType.NOTIFY_FAMILY_PREVIEW;
    }

    @Override
    public AgentActionResult executeAction(AgentActionExecutionContext context, Map<String, Object> payload) {
        var contacts = familyService.listCaregiversForPatient(context.targetUserId());
        String message = "【安康助手提醒】用户于 "
                + LocalDateTime.now().format(DATE_TIME_FORMATTER)
                + " 请求联系家属。请尽快确认其身体状态；如有胸痛、呼吸困难、意识异常等症状，请及时联系急救。";
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("familyContacts", contacts);
        result.put("messagePreview", message);
        result.put("sent", false);
        result.put("recommendedActions", List.of("由用户二次确认后再发送", "紧急情况优先进入 SOS 页面"));
        if (contacts.isEmpty()) {
            return AgentActionResult.success("暂未找到绑定家属，已生成通知内容预览但不会发送。", result);
        }
        return AgentActionResult.success("已准备通知家属的消息预览，尚未发送。", result);
    }
}

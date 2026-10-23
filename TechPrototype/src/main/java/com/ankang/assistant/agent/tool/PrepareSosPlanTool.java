package com.ankang.assistant.agent.tool;

import com.ankang.assistant.agent.action.AgentActionExecutionContext;
import com.ankang.assistant.agent.action.AgentActionResult;
import com.ankang.assistant.agent.action.AgentActionType;
import com.ankang.assistant.emergency.service.EmergencyService;
import com.ankang.assistant.family.service.FamilyService;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Component
public class PrepareSosPlanTool implements AgentTool {

    private static final DateTimeFormatter DATE_TIME_FORMATTER =
            DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    private final NearbyHospitalTool nearbyHospitalTool;
    private final EmergencyService emergencyService;
    private final FamilyService familyService;

    public PrepareSosPlanTool(
            NearbyHospitalTool nearbyHospitalTool,
            EmergencyService emergencyService,
            FamilyService familyService
    ) {
        this.nearbyHospitalTool = nearbyHospitalTool;
        this.emergencyService = emergencyService;
        this.familyService = familyService;
    }

    @Override
    public String name() {
        return "prepare_sos_plan";
    }

    @Override
    public String description() {
        return "Prepare an SOS plan without triggering SOS or notifying contacts.";
    }

    @Override
    public ToolCallResult execute(Map<String, String> arguments) {
        return ToolCallResult.failure(name(), "prepare_sos_plan 只能通过 Agent Action 确认流程执行");
    }

    @Override
    public boolean supportsAction(AgentActionType actionType) {
        return actionType == AgentActionType.PREPARE_SOS_PLAN;
    }

    @Override
    public AgentActionResult executeAction(AgentActionExecutionContext context, Map<String, Object> payload) {
        var hospitals = nearbyHospitalTool.findHospitals(payload);
        var familyContacts = familyService.listCaregiversForPatient(context.targetUserId());
        var emergencyContacts = emergencyService.listContactsByUserId(context.targetUserId());

        String message = "【安康助手SOS预案】"
                + "用户于 " + LocalDateTime.now().format(DATE_TIME_FORMATTER)
                + " 表示身体不适，请尽快联系确认安全。如出现胸痛、呼吸困难、意识异常等症状，请及时联系急救。";
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("nearbyHospitals", hospitals.hospitals());
        result.put("familyContacts", familyContacts);
        result.put("emergencyContacts", emergencyContacts);
        result.put("recommendedMessage", message);
        result.put("recommendedActions", List.of("打开 SOS 页面二次确认", "联系医生或急救", "通知绑定家属"));
        if (hospitals.hospitals().isEmpty()) {
            result.put("locationNotice", "当前没有可用定位，请在 SOS 页面授权定位或手动输入位置。");
        }
        return AgentActionResult.success("SOS 预案已准备完成，尚未发起 SOS，也未通知任何联系人。", result);
    }
}

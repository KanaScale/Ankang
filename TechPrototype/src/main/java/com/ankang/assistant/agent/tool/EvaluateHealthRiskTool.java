package com.ankang.assistant.agent.tool;

import com.ankang.assistant.agent.action.AgentActionExecutionContext;
import com.ankang.assistant.agent.action.AgentActionResult;
import com.ankang.assistant.agent.action.AgentActionType;
import com.ankang.assistant.eventmesh.service.RiskEngineService;
import com.ankang.assistant.eventmesh.vo.RiskAssessment;
import org.springframework.stereotype.Component;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Component
public class EvaluateHealthRiskTool implements AgentTool {

    private final RiskEngineService riskEngineService;

    public EvaluateHealthRiskTool(RiskEngineService riskEngineService) {
        this.riskEngineService = riskEngineService;
    }

    @Override
    public String name() {
        return "evaluate_health_risk";
    }

    @Override
    public String description() {
        return "Evaluate health risk from recent health records and reminder completion status.";
    }

    @Override
    public ToolCallResult execute(Map<String, String> arguments) {
        return ToolCallResult.failure(name(), "evaluate_health_risk 只能通过 Agent Action 流程执行");
    }

    @Override
    public boolean supportsAction(AgentActionType actionType) {
        return actionType == AgentActionType.EVALUATE_HEALTH_RISK;
    }

    @Override
    public AgentActionResult executeAction(AgentActionExecutionContext context, Map<String, Object> payload) {
        RiskAssessment assessment = riskEngineService.assess(context.targetUserId());
        Map<String, Object> risk = new LinkedHashMap<>();
        risk.put("riskLevel", assessment.level());
        risk.put("riskScore", assessment.score());
        risk.put("summary", assessment.summary());
        risk.put("reasons", assessment.reasons());
        risk.put("suggestions", suggestions(assessment.level()));
        risk.put("recommendedActions", recommendedActions(assessment.level()));
        return AgentActionResult.success(assessment.summary(), Map.of("risk", risk));
    }

    private List<String> suggestions(String level) {
        return switch (level) {
            case "high" -> List.of("请尽快联系医生或让患者进入 SOS 流程", "如有胸痛、呼吸困难、意识异常等症状，请立即联系急救");
            case "elevated" -> List.of("建议复测相关指标", "查看最近 7 天趋势并咨询医生");
            default -> List.of("继续保持规律记录和提醒执行");
        };
    }

    private List<String> recommendedActions(String level) {
        return switch (level) {
            case "high" -> List.of("PREPARE_SOS_PLAN", "CONTACT_DOCTOR", "RECHECK");
            case "elevated" -> List.of("RECHECK", "VIEW_TREND", "CONTACT_DOCTOR_IF_PERSISTENT");
            default -> List.of("KEEP_RECORDING");
        };
    }
}

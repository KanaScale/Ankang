package com.ankang.assistant.agent.tool;

import com.ankang.assistant.agent.action.AgentActionExecutionContext;
import com.ankang.assistant.agent.action.AgentActionResult;
import com.ankang.assistant.agent.action.AgentActionType;
import com.ankang.assistant.agent.action.AgentActionValidator;
import com.ankang.assistant.eventmesh.service.RiskEngineService;
import com.ankang.assistant.eventmesh.vo.RiskAssessment;
import com.ankang.assistant.health.dto.HealthRecordCreateDTO;
import com.ankang.assistant.health.service.HealthService;
import com.ankang.assistant.health.vo.HealthRecordVO;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Component
public class RecordHealthDataTool implements AgentTool {

    private final HealthService healthService;
    private final RiskEngineService riskEngineService;
    private final AgentActionValidator validator;

    public RecordHealthDataTool(
            HealthService healthService,
            RiskEngineService riskEngineService,
            AgentActionValidator validator
    ) {
        this.healthService = healthService;
        this.riskEngineService = riskEngineService;
        this.validator = validator;
    }

    @Override
    public String name() {
        return "record_health_data";
    }

    @Override
    public String description() {
        return "Record confirmed health metrics and evaluate health risk.";
    }

    @Override
    public ToolCallResult execute(Map<String, String> arguments) {
        return ToolCallResult.failure(name(), "record_health_data 只能通过 Agent Action 确认流程执行");
    }

    @Override
    public boolean supportsAction(AgentActionType actionType) {
        return actionType == AgentActionType.RECORD_HEALTH_DATA;
    }

    @Override
    public AgentActionResult executeAction(AgentActionExecutionContext context, Map<String, Object> payload) {
        if (!context.patientActor()) {
            return AgentActionResult.failure("家属版 Agent 不能直接录入被照护者健康数据");
        }
        try {
            validator.validateForExecution(AgentActionType.RECORD_HEALTH_DATA, payload, context);
        } catch (RuntimeException ex) {
            return AgentActionResult.failure(ex.getMessage());
        }

        LocalDateTime recordedAt = AgentToolPayloads.dateTime(payload, "recordedAt");
        String remark = AgentToolPayloads.string(payload, "remark");
        List<HealthRecordVO> saved = new ArrayList<>();

        Integer systolic = AgentToolPayloads.integer(payload, "systolic");
        Integer diastolic = AgentToolPayloads.integer(payload, "diastolic");
        if (systolic != null && diastolic != null) {
            saved.add(healthService.createRecord(new HealthRecordCreateDTO(
                    "blood_pressure",
                    null,
                    BigDecimal.valueOf(systolic),
                    BigDecimal.valueOf(diastolic),
                    systolic,
                    diastolic,
                    "mmHg",
                    recordedAt,
                    "agent_action",
                    remark,
                    null
            )));
        }
        BigDecimal heartRate = AgentToolPayloads.decimal(payload, "heartRate");
        if (heartRate != null) {
            saved.add(createSingleValueRecord("heart_rate", heartRate, "bpm", recordedAt, remark));
        }
        BigDecimal bloodGlucose = AgentToolPayloads.decimal(payload, "bloodGlucose");
        if (bloodGlucose != null) {
            saved.add(createSingleValueRecord("blood_glucose", bloodGlucose, "mmol/L", recordedAt, remark));
        }
        BigDecimal weight = AgentToolPayloads.decimal(payload, "weight");
        if (weight != null) {
            saved.add(createSingleValueRecord("weight", weight, "kg", recordedAt, remark));
        }
        if (saved.isEmpty()) {
            return AgentActionResult.failure("未识别到可保存的健康数据");
        }

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("healthRecords", saved);
        List<RiskAssessment> assessments = new ArrayList<>();
        for (HealthRecordVO record : saved) {
            try {
                RiskAssessment risk = riskEngineService.assess(context.targetUserId(), record.id());
                if (risk != null) {
                    assessments.add(risk);
                }
            } catch (RuntimeException ignored) {
                // 风险评估失败不能影响健康数据保存，后面统一返回友好提示。
            }
        }
        if (!assessments.isEmpty()) {
            RiskAssessment primaryRisk = assessments.stream()
                    .max(Comparator.comparingInt(RiskAssessment::score))
                    .orElse(assessments.get(0));
            data.put("risk", riskPayload(primaryRisk));
            data.put("riskAssessments", assessments.stream().map(this::riskPayload).toList());
        } else {
            data.put("riskError", "健康数据已保存，但风险评估暂时不可用");
        }
        return AgentActionResult.success("健康数据已成功记录。", data);
    }

    private HealthRecordVO createSingleValueRecord(
            String type,
            BigDecimal value,
            String unit,
            LocalDateTime recordedAt,
            String remark
    ) {
        return healthService.createRecord(new HealthRecordCreateDTO(
                type,
                value,
                value,
                null,
                null,
                null,
                unit,
                recordedAt,
                "agent_action",
                remark,
                null
        ));
    }

    private Map<String, Object> riskPayload(RiskAssessment risk) {
        List<String> suggestions = "high".equals(risk.level())
                ? List.of("建议静坐休息后再次测量", "如伴随胸痛、呼吸困难等症状，请及时联系医生或进入 SOS 流程")
                : "elevated".equals(risk.level())
                ? List.of("建议复测并观察趋势", "如持续异常，请咨询医生")
                : List.of("继续保持规律记录");
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("riskLevel", risk.level());
        payload.put("riskScore", risk.score());
        payload.put("summary", risk.summary());
        payload.put("reasons", risk.reasons());
        payload.put("suggestions", suggestions);
        return payload;
    }
}

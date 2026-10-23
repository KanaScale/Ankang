package com.ankang.assistant.agent.service;

import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class AgentSafetyService {

    public static final String EMERGENCY_NOTICE = "建议立即联系医生或拨打当地急救电话";

    private static final List<String> EMERGENCY_KEYWORDS = List.of(
            "胸痛", "呼吸困难", "昏迷", "意识不清", "意识丧失", "中风", "抽搐",
            "严重出血", "血糖过低", "严重低血糖", "剧烈头痛", "严重外伤", "持续高烧"
    );

    private static final List<String> MEDICATION_KEYWORDS = List.of(
            "药", "药品", "剂量", "停药", "换药", "副作用", "禁忌", "用法", "用量"
    );

    public boolean hasEmergencyRisk(String message) {
        if (message == null || message.isBlank()) {
            return false;
        }
        return EMERGENCY_KEYWORDS.stream().anyMatch(message::contains);
    }

    public boolean isMedicationRelated(String message) {
        if (message == null || message.isBlank()) {
            return false;
        }
        return MEDICATION_KEYWORDS.stream().anyMatch(message::contains);
    }

    public String safetyInstruction(String message) {
        StringBuilder instruction = new StringBuilder();
        instruction.append("""
                【健康安全边界】
                - 你是健康管理助手，不是医生。
                - 不能给出确诊结论，不能替代医生诊疗。
                - 对不确定信息要明确说明不确定性。
                - 回答要温和、清晰、谨慎。
                - 对药物剂量、停药、换药必须建议遵医嘱。
                - 对胸痛、呼吸困难、意识异常、严重低血糖、中风征象、持续高烧、剧烈头痛、严重外伤等高风险情况，必须建议立即联系医生或拨打当地急救电话。
                """);
        if (hasEmergencyRisk(message)) {
            instruction.append("- 本轮用户描述包含高风险症状，回答必须包含：")
                    .append(EMERGENCY_NOTICE)
                    .append("。\n");
        }
        if (isMedicationRelated(message)) {
            instruction.append("- 本轮涉及药物信息，不能自行建议增减剂量、停药或换药，必须提示遵医嘱。\n");
        }
        return instruction.toString();
    }

    public String enforceEmergencyNotice(String message, String answer) {
        if (!hasEmergencyRisk(message)) {
            return answer;
        }
        String safeAnswer = answer == null ? "" : answer;
        if (safeAnswer.contains(EMERGENCY_NOTICE)) {
            return safeAnswer;
        }
        return EMERGENCY_NOTICE + "。在获得专业帮助前，请避免自行判断或调整药物。\n\n" + safeAnswer;
    }
}

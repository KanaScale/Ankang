package com.ankang.assistant.agent.llm;

import java.util.List;

public class MockAgentLlmClient implements AgentLlmClient {

    @Override
    public String chat(String systemPrompt, List<AgentChatTurn> turns) {
        String lastUserMessage = turns.stream()
                .filter(turn -> "user".equals(turn.role()))
                .reduce((previous, current) -> current)
                .map(AgentChatTurn::content)
                .orElse("");
        if (lastUserMessage.contains("血压")) {
            return "我会结合你的健康摘要和近期记录来判断。当前建议先保持早晚固定时间测量，连续多次高于 140/90 mmHg 或伴随胸痛、头晕时请及时就医。";
        }
        if (lastUserMessage.contains("血糖")) {
            return "血糖问题建议区分空腹和餐后 2 小时记录。若近期波动明显，可以把饮食、运动和用药时间一起记录，方便判断诱因。";
        }
        if (lastUserMessage.contains("药") || lastUserMessage.contains("提醒")) {
            return "可以告诉我药名、剂量和时间。我会帮你整理成提醒建议，但真正创建提醒前仍需要你确认。";
        }
        return "我已经收到你的问题。当前后端没有配置真实模型密钥，所以先返回模拟建议；配置 AGENT_API_KEY 后会切换到真实大模型问答。";
    }

    @Override
    public boolean realModel() {
        return false;
    }
}

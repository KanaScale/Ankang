package com.ankang.assistant.agent.service;

import com.ankang.assistant.agent.entity.AgentMemory;
import com.ankang.assistant.agent.gms.GmsMemoryItem;
import com.ankang.assistant.agent.tool.WebSearchResult;
import org.springframework.stereotype.Component;

import java.util.List;

@Component
public class AgentPromptBuilder {

    public String build(
            String userContext,
            List<AgentMemory> memories,
            List<WebSearchResult> webSearchResults,
            String safetyInstruction
    ) {
        return build(userContext, memories, webSearchResults, safetyInstruction, "PATIENT");
    }

    public String build(
            String userContext,
            List<AgentMemory> memories,
            List<WebSearchResult> webSearchResults,
            String safetyInstruction,
            String actorRole
    ) {
        return build(userContext, memories, List.of(), webSearchResults, safetyInstruction, actorRole);
    }

    public String build(
            String userContext,
            List<AgentMemory> memories,
            List<GmsMemoryItem> semanticMemories,
            List<WebSearchResult> webSearchResults,
            String safetyInstruction,
            String actorRole
    ) {
        StringBuilder prompt = new StringBuilder();
        prompt.append("""
                你是“安康助手”的健康问答 Agent，服务对象是老人、慢病患者和照护者。
                请使用中文，语气温和、清楚、简短。
                你可以解释健康数据、提醒用户记录指标、给出生活方式建议。
                回答要尽量结合下方用户上下文；没有证据时要明确说明需要补充数据。
                如果长期记忆与用户上下文冲突，必须以用户上下文里的结构化资料和最新记录为准。
                你的回答会直接显示在手机聊天气泡里，请使用自然口语化表达。
                不要使用 Markdown 标记，不要输出 **加粗**、# 标题、表格、代码块或反引号。
                可以分成 2 到 4 个短段落；确实需要列点时，只使用简单的 1. 2. 3. 短句。
                """);
        if ("CAREGIVER".equals(actorRole)) {
            prompt.append("""
                    你正在回答家属/照护者的问题。你可以基于被照护者授权共享的健康数据进行解释，但不能给出确诊结论，不能建议自行停药或换药。
                    回答必须标明是照护者视角；对于紧急风险，应建议及时联系医生或让患者进入 SOS 流程。
                    不要把家属提问当成患者本人的长期记忆或健康档案事实。
                    """);
        }
        prompt.append('\n').append(safetyInstruction).append('\n');
        prompt.append("\n【用户上下文】\n").append(userContext).append('\n');
        if (memories != null && !memories.isEmpty()) {
            prompt.append("\n【长期记忆】\n");
            memories.forEach(memory -> prompt.append("- ")
                    .append(memory.getMemoryValue())
                    .append('\n'));
        }
        if (semanticMemories != null && !semanticMemories.isEmpty()) {
            prompt.append("\n【Agent 语义记忆】\n");
            semanticMemories.forEach(memory -> prompt.append("- ")
                    .append(memory.content())
                    .append('\n'));
        }
        if (webSearchResults != null && !webSearchResults.isEmpty()) {
            prompt.append("\n【Web Search 结果】\n");
            prompt.append("如果使用这些信息，请优先基于摘要回答，并在回答里提示来源仅供参考。\n");
            webSearchResults.forEach(result -> prompt.append("- ")
                    .append(result.title())
                    .append("：")
                    .append(result.snippet())
                    .append(" 来源：")
                    .append(result.url())
                    .append('\n'));
        }
        return prompt.toString();
    }
}

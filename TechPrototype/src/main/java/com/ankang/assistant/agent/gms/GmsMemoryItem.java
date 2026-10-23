package com.ankang.assistant.agent.gms;

public record GmsMemoryItem(
        String content,
        String dataType,
        String sourceApp,
        Double score
) {
}

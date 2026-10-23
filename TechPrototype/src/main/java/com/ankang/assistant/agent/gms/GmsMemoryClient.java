package com.ankang.assistant.agent.gms;

import java.util.List;

public interface GmsMemoryClient {

    void addMemoryAsync(Long userId, String sourceApp, String content, String dataType, List<String> contextTags);

    List<GmsMemoryItem> searchMemories(Long userId, String query);

    static GmsMemoryClient disabled() {
        return new GmsMemoryClient() {
            @Override
            public void addMemoryAsync(
                    Long userId,
                    String sourceApp,
                    String content,
                    String dataType,
                    List<String> contextTags
            ) {
                // no-op
            }

            @Override
            public List<GmsMemoryItem> searchMemories(Long userId, String query) {
                return List.of();
            }
        };
    }
}

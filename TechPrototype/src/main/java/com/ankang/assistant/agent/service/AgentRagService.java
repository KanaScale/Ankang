package com.ankang.assistant.agent.service;

import com.ankang.assistant.agent.config.AgentProperties;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class AgentRagService {

    private final AgentProperties properties;

    public AgentRagService(AgentProperties properties) {
        this.properties = properties;
    }

    public List<String> retrieve(Long userId, String query) {
        // Qdrant 配置已进入 AgentProperties；第一版先不强依赖外部向量库，
        // 避免 Qdrant 未启动时影响首页问答。后续在这里接入向量检索。
        if (properties.getQdrant() == null || query == null || query.isBlank()) {
            return List.of();
        }
        return List.of();
    }
}

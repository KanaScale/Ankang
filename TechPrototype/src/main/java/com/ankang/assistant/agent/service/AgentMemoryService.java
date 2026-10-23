package com.ankang.assistant.agent.service;

import com.ankang.assistant.agent.entity.AgentMemory;
import com.ankang.assistant.agent.mapper.AgentMemoryMapper;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class AgentMemoryService {

    private static final int MEMORY_LIMIT = 8;

    private final AgentMemoryMapper memoryMapper;

    public AgentMemoryService(AgentMemoryMapper memoryMapper) {
        this.memoryMapper = memoryMapper;
    }

    public List<AgentMemory> listMemories(Long userId) {
        return memoryMapper.selectList(new LambdaQueryWrapper<AgentMemory>()
                .eq(AgentMemory::getUserId, userId)
                .orderByDesc(AgentMemory::getUpdatedAt)
                .orderByDesc(AgentMemory::getId)
                .last("LIMIT " + MEMORY_LIMIT));
    }

    public void rememberExplicitUserFact(Long userId, String message) {
        String key = extractMemoryKey(message);
        if (key == null) {
            return;
        }
        AgentMemory existing = memoryMapper.selectOne(new LambdaQueryWrapper<AgentMemory>()
                .eq(AgentMemory::getUserId, userId)
                .eq(AgentMemory::getMemoryKey, key));
        if (existing == null) {
            AgentMemory memory = new AgentMemory();
            memory.setUserId(userId);
            memory.setMemoryKey(key);
            memory.setMemoryValue(message.trim());
            memory.setSource("chat");
            memoryMapper.insert(memory);
        } else {
            existing.setMemoryValue(message.trim());
            memoryMapper.updateById(existing);
        }
    }

    private String extractMemoryKey(String message) {
        if (message == null || message.isBlank()) {
            return null;
        }
        String text = message.trim();
        if (text.contains("过敏")) {
            return "allergy";
        }
        if (text.contains("高血压") || text.contains("糖尿病") || text.contains("慢病") || text.contains("冠心病")) {
            return "chronic_disease";
        }
        if (text.contains("长期吃") || text.contains("长期服用") || text.contains("每天吃") || text.contains("用药")) {
            return "medication";
        }
        if (text.contains("运动习惯") || text.contains("每天走") || text.contains("每周运动") || text.contains("跑步")) {
            return "exercise_habit";
        }
        if (text.contains("忌口") || text.contains("饮食限制") || text.contains("不能吃") || text.contains("少盐")) {
            return "diet_limit";
        }
        if (text.contains("照护") || text.contains("家人提醒") || text.contains("医生建议")) {
            return "care_preference";
        }
        if (text.contains("记住") && (text.contains("健康") || text.contains("医生") || text.contains("药") || text.contains("病"))) {
            return "health_note";
        }
        return null;
    }
}

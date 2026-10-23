package com.ankang.assistant.agent.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("agent_memory")
public class AgentMemory {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long userId;
    private String memoryKey;
    private String memoryValue;
    private String source;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}

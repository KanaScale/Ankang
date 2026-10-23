package com.ankang.assistant.agent.action;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("agent_action")
public class AgentAction {
    @TableId(type = IdType.AUTO)
    private Long id;
    private String actionId;
    private Long userId;
    private Long targetUserId;
    private String actorRole;
    private Long sessionId;
    private String actionType;
    private String status;
    private String payload;
    private String result;
    private String errorMessage;
    private LocalDateTime expiresAt;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}

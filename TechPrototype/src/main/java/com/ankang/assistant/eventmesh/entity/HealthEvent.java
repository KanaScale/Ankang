package com.ankang.assistant.eventmesh.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("health_event")
public class HealthEvent {
    @TableId(type = IdType.AUTO)
    private Long id;
    private String eventId;
    private Long userId;
    private String eventType;
    private Long aggregateId;
    private String status;
    private String riskLevel;
    private Integer riskScore;
    private String summary;
    private String reasonsJson;
    private Long sosEventId;
    private LocalDateTime occurredAt;
    private LocalDateTime processedAt;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}

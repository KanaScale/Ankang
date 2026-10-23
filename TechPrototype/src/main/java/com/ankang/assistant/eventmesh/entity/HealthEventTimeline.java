package com.ankang.assistant.eventmesh.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("health_event_timeline")
public class HealthEventTimeline {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long healthEventId;
    private String stage;
    private String message;
    private LocalDateTime occurredAt;
}

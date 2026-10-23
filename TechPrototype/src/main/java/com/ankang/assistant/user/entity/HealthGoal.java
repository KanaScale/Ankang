package com.ankang.assistant.user.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("health_goal")
public class HealthGoal {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long userId;
    private String stepsTarget;
    private String stepsNote;
    private String sleepTarget;
    private String sleepNote;
    private String bloodPressureTarget;
    private String bloodPressureNote;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}

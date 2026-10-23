package com.ankang.assistant.emergency.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("emergency_delivery_attempt")
public class EmergencyDeliveryAttempt {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long eventId;
    private Long userId;
    private String attemptId;
    private Long contactId;
    private String channel;
    private String status;
    private String errorCode;
    private LocalDateTime occurredAt;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}

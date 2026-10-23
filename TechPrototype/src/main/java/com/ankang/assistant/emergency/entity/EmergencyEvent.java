package com.ankang.assistant.emergency.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@TableName("emergency_event")
public class EmergencyEvent {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long userId;
    private String clientEventId;
    private LocalDateTime triggeredAt;
    private BigDecimal latitude;
    private BigDecimal longitude;
    private BigDecimal accuracyMeters;
    private String locationSource;
    private String address;
    private String message;
    private String status;
    private Integer contactsNotified;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}

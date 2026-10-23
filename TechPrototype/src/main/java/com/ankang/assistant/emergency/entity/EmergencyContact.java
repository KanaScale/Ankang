package com.ankang.assistant.emergency.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("emergency_contact")
public class EmergencyContact {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long userId;
    private String clientContactId;
    private String name;
    private String relation;
    private String relationship;
    private String phone;
    private Integer priority;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}

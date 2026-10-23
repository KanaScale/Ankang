package com.ankang.assistant.user.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@TableName("health_profile")
public class HealthProfile {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long userId;
    private BigDecimal height;
    private BigDecimal weight;
    private String chronicDiseases;
    private String allergies;
    private String medicalHistory;
    private String device;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}

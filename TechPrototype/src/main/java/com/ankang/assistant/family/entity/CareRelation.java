package com.ankang.assistant.family.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("care_relation")
public class CareRelation {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long patientUserId;
    private Long caregiverUserId;
    private String relationType;
    private String permissions;
    private String status;
    private String inviteCode;
    private LocalDateTime inviteExpireAt;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}

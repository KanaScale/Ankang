package com.ankang.assistant.user.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@TableName("user_setting")
public class UserSetting {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long userId;
    private BigDecimal fontScale;
    private Boolean notificationEnabled;
    private Boolean largeTouchTarget;
    private Boolean simpleMode;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}

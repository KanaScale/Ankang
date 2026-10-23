package com.ankang.assistant.device.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("device_bind")
public class DeviceBind {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long userId;
    private String deviceName;
    private String deviceType;
    private String provider;
    private String bindStatus;
    private LocalDateTime lastSyncAt;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}

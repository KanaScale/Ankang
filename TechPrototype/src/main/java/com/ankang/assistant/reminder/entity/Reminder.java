package com.ankang.assistant.reminder.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;

@Data
@TableName("reminder")
public class Reminder {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long userId;
    private String clientReminderId;
    private String title;
    private String type;
    private String description;
    private String remark;
    private LocalDateTime remindAt;
    private LocalTime remindTime;
    private String repeatType;
    private Boolean enabled;
    private Boolean completed;
    private LocalDate lastCompletedDate;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}

package com.ankang.assistant.user.dto;

import java.math.BigDecimal;

public record UserSettingUpdateDTO(
        BigDecimal fontScale,
        Boolean notificationEnabled,
        Boolean largeTouchTarget,
        Boolean simpleMode
) {
}

package com.ankang.assistant.user.vo;

import java.math.BigDecimal;

public record UserSettingVO(
        BigDecimal fontScale,
        Boolean notificationEnabled,
        Boolean largeTouchTarget,
        Boolean simpleMode
) {
}

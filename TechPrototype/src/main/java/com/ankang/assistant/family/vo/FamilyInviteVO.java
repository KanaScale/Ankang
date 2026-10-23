package com.ankang.assistant.family.vo;

import java.time.LocalDateTime;

public record FamilyInviteVO(
        String inviteCode,
        LocalDateTime expireAt
) {
}

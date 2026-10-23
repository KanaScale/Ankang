package com.ankang.assistant.auth.vo;

import java.time.LocalDateTime;

public record AuthTokenVO(
        String token,
        String refreshToken,
        long accessTokenExpiresInSeconds,
        LocalDateTime refreshTokenExpiresAt
) {
}

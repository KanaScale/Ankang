package com.ankang.assistant.auth.vo;

import com.ankang.assistant.user.vo.UserProfileVO;

public record LoginVO(
        String token,
        String refreshToken,
        long accessTokenExpiresInSeconds,
        java.time.LocalDateTime refreshTokenExpiresAt,
        UserProfileVO user
) {
}

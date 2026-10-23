package com.ankang.assistant.config;

import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

public final class SecurityUtils {

    private SecurityUtils() {
    }

    public static JwtService.JwtUser currentUser() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null || !(authentication.getPrincipal() instanceof JwtService.JwtUser jwtUser)) {
            throw new IllegalArgumentException("未登录或登录状态已失效");
        }
        return jwtUser;
    }

    public static Long currentUserId() {
        return currentUser().userId();
    }
}

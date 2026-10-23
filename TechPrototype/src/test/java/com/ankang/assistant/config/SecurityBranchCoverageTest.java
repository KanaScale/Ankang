package com.ankang.assistant.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class SecurityBranchCoverageTest {

    @AfterEach
    void clearContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void securityUtilsRejectsMissingAndWrongPrincipal() {
        assertThatThrownBy(SecurityUtils::currentUser)
                .isInstanceOf(IllegalArgumentException.class);

        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken("not-a-jwt-user", null));
        assertThatThrownBy(SecurityUtils::currentUser)
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void jwtCoversNullSubjectAndDifferentSignatureLengths() {
        JwtService service = new JwtService(new ObjectMapper(), "branch-secret", 3600);
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("sub", null);
        payload.put("uid", 7);
        payload.put("exp", Instant.now().getEpochSecond() + 60);

        assertThatThrownBy(() -> service.parseToken(customToken(service, payload)))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("用户信息");
        assertThat((Boolean) ReflectionTestUtils.invokeMethod(
                service, "constantTimeEquals", "a", "aa")).isFalse();
    }

    private String customToken(JwtService service, Map<String, Object> payload) {
        String header = ReflectionTestUtils.invokeMethod(
                service, "encodeJson", Map.of("alg", "HS256", "typ", "JWT"));
        String body = ReflectionTestUtils.invokeMethod(service, "encodeJson", payload);
        String unsigned = header + "." + body;
        String signature = ReflectionTestUtils.invokeMethod(service, "sign", unsigned);
        return unsigned + "." + signature;
    }
}

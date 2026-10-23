package com.ankang.assistant.config;

import com.ankang.assistant.user.entity.User;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class JwtServiceTest {

    @Test
    void generatesAndParsesSignedToken() {
        JwtService service = new JwtService(new ObjectMapper(), "unit-test-secret", 3600);
        User user = new User();
        user.setId(42L);
        user.setUsername("alice");

        String token = service.generateToken(user);
        JwtService.JwtUser principal = service.parseToken(token);

        assertThat(principal.userId()).isEqualTo(42L);
        assertThat(principal.username()).isEqualTo("alice");
        assertThat(service.getExpirationSeconds()).isEqualTo(3600);
    }

    @Test
    void rejectsMalformedTamperedExpiredAndInvalidPayloadTokens() {
        JwtService service = new JwtService(new ObjectMapper(), "unit-test-secret", 3600);
        assertThatThrownBy(() -> service.parseToken(null)).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> service.parseToken("a.b")).isInstanceOf(IllegalArgumentException.class);

        User user = new User();
        user.setId(1L);
        user.setUsername("user");
        String token = service.generateToken(user);
        assertThatThrownBy(() -> service.parseToken(token.substring(0, token.length() - 1) + "x"))
                .isInstanceOf(IllegalArgumentException.class);
        String[] parts = token.split("\\.");
        assertThatThrownBy(() -> service.parseToken(parts[0] + ".%%%." + parts[2]))
                .isInstanceOf(IllegalArgumentException.class);

        JwtService expired = new JwtService(new ObjectMapper(), "unit-test-secret", -1);
        assertThatThrownBy(() -> expired.parseToken(expired.generateToken(user)))
                .isInstanceOf(IllegalArgumentException.class);

        assertThatThrownBy(() -> service.parseToken(customToken(service, Map.of(
                "sub", "", "uid", 1, "exp", Instant.now().getEpochSecond() + 60
        )))).isInstanceOf(IllegalArgumentException.class);
        Map<String, Object> missingId = new LinkedHashMap<>();
        missingId.put("sub", "user");
        missingId.put("uid", null);
        missingId.put("exp", Instant.now().getEpochSecond() + 60);
        assertThatThrownBy(() -> service.parseToken(customToken(service, missingId)))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void parsesStringNumericClaimsAndRejectsNonNumericClaims() {
        JwtService service = new JwtService(new ObjectMapper(), "unit-test-secret", 3600);
        String good = customToken(service, Map.of(
                "sub", "bob",
                "uid", "7",
                "exp", String.valueOf(Instant.now().getEpochSecond() + 60)
        ));
        assertThat(service.parseToken(good).userId()).isEqualTo(7L);

        String bad = customToken(service, Map.of(
                "sub", "bob",
                "uid", Map.of("bad", true),
                "exp", Instant.now().getEpochSecond() + 60
        ));
        assertThatThrownBy(() -> service.parseToken(bad)).isInstanceOf(IllegalArgumentException.class);
    }

    private String customToken(JwtService service, Map<String, Object> payload) {
        String header = ReflectionTestUtils.invokeMethod(
                service, "encodeJson", Map.of("alg", "HS256", "typ", "JWT")
        );
        String body = ReflectionTestUtils.invokeMethod(service, "encodeJson", payload);
        String unsigned = header + "." + body;
        String signature = ReflectionTestUtils.invokeMethod(service, "sign", unsigned);
        return unsigned + "." + signature;
    }
}

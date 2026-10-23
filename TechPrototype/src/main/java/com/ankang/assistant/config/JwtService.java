package com.ankang.assistant.config;

import com.ankang.assistant.user.entity.User;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.Map;

@Service
public class JwtService {

    private static final String HMAC_SHA256 = "HmacSHA256";
    private static final Base64.Encoder BASE64_URL_ENCODER = Base64.getUrlEncoder().withoutPadding();
    private static final Base64.Decoder BASE64_URL_DECODER = Base64.getUrlDecoder();

    private final ObjectMapper objectMapper;
    private final byte[] secret;
    private final long expirationSeconds;

    public JwtService(
            ObjectMapper objectMapper,
            @Value("${auth.jwt.secret}") String secret,
            @Value("${auth.jwt.expiration-seconds:86400}") long expirationSeconds
    ) {
        this.objectMapper = objectMapper;
        this.secret = secret.getBytes(StandardCharsets.UTF_8);
        this.expirationSeconds = expirationSeconds;
    }

    public String generateToken(User user) {
        long now = Instant.now().getEpochSecond();
        Map<String, Object> header = new LinkedHashMap<>();
        header.put("alg", "HS256");
        header.put("typ", "JWT");

        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("sub", user.getUsername());
        payload.put("uid", user.getId());
        payload.put("iat", now);
        payload.put("exp", now + expirationSeconds);

        String headerPart = encodeJson(header);
        String payloadPart = encodeJson(payload);
        String unsignedToken = headerPart + "." + payloadPart;
        return unsignedToken + "." + sign(unsignedToken);
    }

    public long getExpirationSeconds() {
        return expirationSeconds;
    }

    public JwtUser parseToken(String token) {
        String[] parts = token == null ? new String[0] : token.split("\\.");
        if (parts.length != 3) {
            throw new IllegalArgumentException("令牌格式错误");
        }

        String unsignedToken = parts[0] + "." + parts[1];
        String expectedSignature = sign(unsignedToken);
        if (!constantTimeEquals(expectedSignature, parts[2])) {
            throw new IllegalArgumentException("令牌签名无效");
        }

        Map<String, Object> payload = decodeJson(parts[1]);
        long expiresAt = asLong(payload.get("exp"));
        if (expiresAt <= Instant.now().getEpochSecond()) {
            throw new IllegalArgumentException("令牌已过期");
        }

        String username = payload.get("sub") == null ? "" : payload.get("sub").toString();
        Long userId = asLong(payload.get("uid"));
        if (username.isBlank() || userId == null) {
            throw new IllegalArgumentException("令牌缺少用户信息");
        }
        return new JwtUser(userId, username);
    }

    private String encodeJson(Map<String, Object> value) {
        try {
            byte[] json = objectMapper.writeValueAsBytes(value);
            return BASE64_URL_ENCODER.encodeToString(json);
        } catch (JsonProcessingException ex) {
            throw new IllegalStateException("JWT 序列化失败", ex);
        }
    }

    private Map<String, Object> decodeJson(String value) {
        try {
            byte[] json = BASE64_URL_DECODER.decode(value);
            return objectMapper.readValue(json, new TypeReference<>() {
            });
        } catch (IllegalArgumentException | IOException ex) {
            throw new IllegalArgumentException("令牌内容无效", ex);
        }
    }

    private String sign(String value) {
        try {
            Mac mac = Mac.getInstance(HMAC_SHA256);
            mac.init(new SecretKeySpec(secret, HMAC_SHA256));
            byte[] signature = mac.doFinal(value.getBytes(StandardCharsets.UTF_8));
            return BASE64_URL_ENCODER.encodeToString(signature);
        } catch (Exception ex) {
            throw new IllegalStateException("JWT 签名失败", ex);
        }
    }

    private boolean constantTimeEquals(String first, String second) {
        byte[] firstBytes = first.getBytes(StandardCharsets.UTF_8);
        byte[] secondBytes = second.getBytes(StandardCharsets.UTF_8);
        if (firstBytes.length != secondBytes.length) {
            return false;
        }
        int result = 0;
        for (int index = 0; index < firstBytes.length; index++) {
            result |= firstBytes[index] ^ secondBytes[index];
        }
        return result == 0;
    }

    private Long asLong(Object value) {
        if (value instanceof Number number) {
            return number.longValue();
        }
        if (value instanceof String text) {
            return Long.parseLong(text);
        }
        return null;
    }

    public record JwtUser(Long userId, String username) {
    }
}

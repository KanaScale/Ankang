package com.ankang.assistant.auth.service;

import com.ankang.assistant.auth.entity.AuthRefreshSession;
import com.ankang.assistant.auth.mapper.AuthRefreshSessionMapper;
import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.UpdateWrapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.Base64;
import java.util.HexFormat;

@Service
public class AuthRefreshTokenService {

    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    private final AuthRefreshSessionMapper sessionMapper;
    private final long expirationDays;

    public AuthRefreshTokenService(
            AuthRefreshSessionMapper sessionMapper,
            @Value("${auth.refresh.expiration-days:30}") long expirationDays
    ) {
        this.sessionMapper = sessionMapper;
        this.expirationDays = expirationDays;
    }

    @Transactional
    public IssuedRefreshToken issue(Long userId) {
        byte[] randomBytes = new byte[32];
        SECURE_RANDOM.nextBytes(randomBytes);
        String rawToken = Base64.getUrlEncoder().withoutPadding().encodeToString(randomBytes);
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime expiresAt = now.plusDays(expirationDays);

        AuthRefreshSession session = new AuthRefreshSession();
        session.setUserId(userId);
        session.setTokenHash(hash(rawToken));
        session.setExpiresAt(expiresAt);
        session.setCreatedAt(now);
        session.setLastUsedAt(now);
        sessionMapper.insert(session);
        return new IssuedRefreshToken(rawToken, expiresAt);
    }

    @Transactional
    public RotatedRefreshToken rotate(String rawToken) {
        String tokenHash = hash(rawToken);
        AuthRefreshSession current = sessionMapper.selectOne(
                new QueryWrapper<AuthRefreshSession>()
                        .eq("token_hash", tokenHash)
                        .last("limit 1")
        );
        LocalDateTime now = LocalDateTime.now();
        if (current == null || current.getRevokedAt() != null
                || current.getExpiresAt() == null || !current.getExpiresAt().isAfter(now)) {
            throw new AuthSessionException("登录状态已失效，请重新登录");
        }

        int revoked = sessionMapper.update(
                null,
                new UpdateWrapper<AuthRefreshSession>()
                        .eq("id", current.getId())
                        .isNull("revoked_at")
                        .gt("expires_at", now)
                        .set("revoked_at", now)
                        .set("last_used_at", now)
        );
        if (revoked != 1) {
            throw new AuthSessionException("登录状态已被使用，请重新登录");
        }
        IssuedRefreshToken issued = issue(current.getUserId());
        return new RotatedRefreshToken(current.getUserId(), issued.token(), issued.expiresAt());
    }

    public void revoke(String rawToken) {
        if (rawToken == null || rawToken.isBlank()) {
            return;
        }
        LocalDateTime now = LocalDateTime.now();
        sessionMapper.update(
                null,
                new UpdateWrapper<AuthRefreshSession>()
                        .eq("token_hash", hash(rawToken))
                        .isNull("revoked_at")
                        .set("revoked_at", now)
                        .set("last_used_at", now)
        );
    }

    public void revokeAll(Long userId) {
        LocalDateTime now = LocalDateTime.now();
        sessionMapper.update(
                null,
                new UpdateWrapper<AuthRefreshSession>()
                        .eq("user_id", userId)
                        .isNull("revoked_at")
                        .set("revoked_at", now)
                        .set("last_used_at", now)
        );
    }

    private String hash(String rawToken) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(
                    digest.digest(rawToken.getBytes(StandardCharsets.UTF_8))
            );
        } catch (NoSuchAlgorithmException ex) {
            throw new IllegalStateException("刷新令牌摘要算法不可用", ex);
        }
    }

    public record IssuedRefreshToken(String token, LocalDateTime expiresAt) {
    }

    public record RotatedRefreshToken(Long userId, String token, LocalDateTime expiresAt) {
    }
}

package com.ankang.assistant.auth.service;

import com.ankang.assistant.auth.entity.AuthRefreshSession;
import com.ankang.assistant.auth.mapper.AuthRefreshSessionMapper;
import com.baomidou.mybatisplus.core.conditions.Wrapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDateTime;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AuthRefreshTokenServiceTest {

    @Mock
    private AuthRefreshSessionMapper sessionMapper;

    @Test
    void issueShouldPersistOnlyTokenHash() {
        AuthRefreshTokenService service = new AuthRefreshTokenService(sessionMapper, 30);

        AuthRefreshTokenService.IssuedRefreshToken issued = service.issue(7L);

        ArgumentCaptor<AuthRefreshSession> captor =
                ArgumentCaptor.forClass(AuthRefreshSession.class);
        verify(sessionMapper).insert(captor.capture());
        AuthRefreshSession saved = captor.getValue();
        assertThat(issued.token()).isNotBlank();
        assertThat(saved.getTokenHash()).hasSize(64).doesNotContain(issued.token());
        assertThat(saved.getUserId()).isEqualTo(7L);
        assertThat(issued.expiresAt()).isAfter(LocalDateTime.now().plusDays(29));
    }

    @Test
    void rotateShouldRevokeOldSessionAndIssueReplacement() {
        AuthRefreshSession current = activeSession();
        when(sessionMapper.selectOne(any(Wrapper.class))).thenReturn(current);
        when(sessionMapper.update(any(), any(Wrapper.class))).thenReturn(1);
        AuthRefreshTokenService service = new AuthRefreshTokenService(sessionMapper, 30);

        AuthRefreshTokenService.RotatedRefreshToken rotated =
                service.rotate("old-refresh-token");

        assertThat(rotated.userId()).isEqualTo(7L);
        assertThat(rotated.token()).isNotBlank().isNotEqualTo("old-refresh-token");
        verify(sessionMapper).update(any(), any(Wrapper.class));
        verify(sessionMapper).insert(any(AuthRefreshSession.class));
    }

    @Test
    void rotateShouldRejectConcurrentReuse() {
        AuthRefreshSession current = activeSession();
        when(sessionMapper.selectOne(any(Wrapper.class))).thenReturn(current);
        when(sessionMapper.update(any(), any(Wrapper.class))).thenReturn(0);
        AuthRefreshTokenService service = new AuthRefreshTokenService(sessionMapper, 30);

        assertThatThrownBy(() -> service.rotate("already-used-token"))
                .isInstanceOf(AuthSessionException.class)
                .hasMessageContaining("已被使用");
    }

    @Test
    void rotateShouldRejectExpiredSession() {
        AuthRefreshSession current = activeSession();
        current.setExpiresAt(LocalDateTime.now().minusMinutes(1));
        when(sessionMapper.selectOne(any(Wrapper.class))).thenReturn(current);
        AuthRefreshTokenService service = new AuthRefreshTokenService(sessionMapper, 30);

        assertThatThrownBy(() -> service.rotate("expired-token"))
                .isInstanceOf(AuthSessionException.class)
                .hasMessageContaining("已失效");
    }

    @Test
    void rotateRejectsMissingRevokedAndMissingExpirationSessions() {
        AuthRefreshTokenService service = new AuthRefreshTokenService(sessionMapper, 30);
        when(sessionMapper.selectOne(any(Wrapper.class))).thenReturn(null);
        assertThatThrownBy(() -> service.rotate("missing")).isInstanceOf(AuthSessionException.class);

        AuthRefreshSession revoked = activeSession();
        revoked.setRevokedAt(LocalDateTime.now());
        when(sessionMapper.selectOne(any(Wrapper.class))).thenReturn(revoked);
        assertThatThrownBy(() -> service.rotate("revoked")).isInstanceOf(AuthSessionException.class);

        AuthRefreshSession noExpiry = activeSession();
        noExpiry.setExpiresAt(null);
        when(sessionMapper.selectOne(any(Wrapper.class))).thenReturn(noExpiry);
        assertThatThrownBy(() -> service.rotate("no-expiry")).isInstanceOf(AuthSessionException.class);
    }

    @Test
    void revokeHandlesBlankTokenAndRevokeAllUpdatesMatchingSessions() {
        AuthRefreshTokenService service = new AuthRefreshTokenService(sessionMapper, 30);
        service.revoke(null);
        service.revoke(" ");
        verify(sessionMapper, never()).update(any(), any(Wrapper.class));

        service.revoke("token");
        service.revokeAll(7L);
        verify(sessionMapper, org.mockito.Mockito.times(2)).update(any(), any(Wrapper.class));
    }

    private AuthRefreshSession activeSession() {
        AuthRefreshSession session = new AuthRefreshSession();
        session.setId(11L);
        session.setUserId(7L);
        session.setTokenHash("a".repeat(64));
        session.setExpiresAt(LocalDateTime.now().plusDays(1));
        return session;
    }
}

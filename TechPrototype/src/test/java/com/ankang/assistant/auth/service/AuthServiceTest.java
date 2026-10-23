package com.ankang.assistant.auth.service;

import com.ankang.assistant.auth.dto.RegisterDTO;
import com.ankang.assistant.auth.dto.LoginDTO;
import com.ankang.assistant.auth.dto.LogoutDTO;
import com.ankang.assistant.auth.dto.PasswordResetCodeDTO;
import com.ankang.assistant.auth.dto.PasswordResetDTO;
import com.ankang.assistant.auth.dto.RefreshTokenDTO;
import com.ankang.assistant.auth.vo.AuthTokenVO;
import com.ankang.assistant.auth.vo.LoginVO;
import com.ankang.assistant.auth.vo.RegisterVO;
import com.ankang.assistant.config.JwtService;
import com.ankang.assistant.user.entity.User;
import com.ankang.assistant.user.mapper.UserMapper;
import com.baomidou.mybatisplus.core.conditions.Wrapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.security.crypto.password.PasswordEncoder;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    @Mock
    private UserMapper userMapper;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private JwtService jwtService;

    @Mock
    private StringRedisTemplate redisTemplate;

    @Mock
    private AuthRefreshTokenService refreshTokenService;

    @Mock
    private ValueOperations<String, String> valueOperations;

    @InjectMocks
    private AuthService authService;

    @Test
    void registerShouldEncodePasswordAndSaveUser() {
        when(userMapper.selectCount(any(Wrapper.class))).thenReturn(0L);
        when(passwordEncoder.encode("secret123")).thenReturn("encoded-password");
        when(userMapper.insert(any(User.class))).thenAnswer(invocation -> {
            User user = invocation.getArgument(0);
            user.setId(101L);
            return 1;
        });

        RegisterVO result = authService.register(
                new RegisterDTO(" alice ", "secret123", "secret123", " 13800138000 ")
        );

        assertThat(result.id()).isEqualTo(101L);
        assertThat(result.username()).isEqualTo("alice");

        ArgumentCaptor<User> userCaptor = ArgumentCaptor.forClass(User.class);
        verify(userMapper).insert(userCaptor.capture());
        User savedUser = userCaptor.getValue();
        assertThat(savedUser.getUsername()).isEqualTo("alice");
        assertThat(savedUser.getNickname()).isEqualTo("alice");
        assertThat(savedUser.getPasswordHash()).isEqualTo("encoded-password");
        assertThat(savedUser.getPhone()).isEqualTo("13800138000");
        verify(passwordEncoder).encode("secret123");
    }

    @Test
    void registerShouldRejectDuplicateUsernameWithoutSaving() {
        when(userMapper.selectCount(any(Wrapper.class))).thenReturn(1L);

        assertThatThrownBy(() -> authService.register(
                new RegisterDTO("alice", "secret123", "secret123", null)
        ))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("用户名已存在");

        verify(passwordEncoder, never()).encode(any());
        verify(userMapper, never()).insert(any(User.class));
    }

    @Test
    void loginShouldIssueRefreshTokenWhenKeepSignedIn() {
        User user = new User();
        user.setId(9L);
        user.setUsername("alice");
        user.setPasswordHash("encoded-password");
        when(redisTemplate.opsForValue()).thenReturn(valueOperations);
        when(valueOperations.get(any())).thenReturn(null);
        when(userMapper.selectOne(any(Wrapper.class))).thenReturn(user);
        when(passwordEncoder.matches("secret123", "encoded-password"))
                .thenReturn(true);
        when(jwtService.generateToken(user)).thenReturn("access-token");
        when(jwtService.getExpirationSeconds()).thenReturn(900L);
        when(refreshTokenService.issue(9L)).thenReturn(
                new AuthRefreshTokenService.IssuedRefreshToken(
                        "refresh-token",
                        java.time.LocalDateTime.now().plusDays(30)
                )
        );

        LoginVO result = authService.login(
                new LoginDTO("alice", "secret123", true)
        );

        assertThat(result.token()).isEqualTo("access-token");
        assertThat(result.refreshToken()).isEqualTo("refresh-token");
        assertThat(result.accessTokenExpiresInSeconds()).isEqualTo(900L);
        verify(refreshTokenService).issue(9L);
    }

    @Test
    void loginShouldNotIssueRefreshTokenWithoutKeepSignedIn() {
        User user = new User();
        user.setId(9L);
        user.setUsername("alice");
        user.setPasswordHash("encoded-password");
        when(redisTemplate.opsForValue()).thenReturn(valueOperations);
        when(valueOperations.get(any())).thenReturn(null);
        when(userMapper.selectOne(any(Wrapper.class))).thenReturn(user);
        when(passwordEncoder.matches("secret123", "encoded-password"))
                .thenReturn(true);
        when(jwtService.generateToken(user)).thenReturn("access-token");
        when(jwtService.getExpirationSeconds()).thenReturn(900L);

        LoginVO result = authService.login(
                new LoginDTO("alice", "secret123", false)
        );

        assertThat(result.refreshToken()).isNull();
        verify(refreshTokenService, never()).issue(any());
    }

    @Test
    void refreshShouldRotateTokenAndIssueNewAccessToken() {
        User user = new User();
        user.setId(9L);
        user.setUsername("alice");
        java.time.LocalDateTime expiresAt =
                java.time.LocalDateTime.now().plusDays(30);
        when(refreshTokenService.rotate("old-refresh")).thenReturn(
                new AuthRefreshTokenService.RotatedRefreshToken(
                        9L,
                        "new-refresh",
                        expiresAt
                )
        );
        when(userMapper.selectById(9L)).thenReturn(user);
        when(jwtService.generateToken(user)).thenReturn("new-access");
        when(jwtService.getExpirationSeconds()).thenReturn(900L);

        AuthTokenVO result =
                authService.refresh(new RefreshTokenDTO("old-refresh"));

        assertThat(result.token()).isEqualTo("new-access");
        assertThat(result.refreshToken()).isEqualTo("new-refresh");
        assertThat(result.refreshTokenExpiresAt()).isEqualTo(expiresAt);
    }

    @Test
    void logoutShouldRevokeRefreshToken() {
        authService.logout(new LogoutDTO("refresh-token"));

        verify(refreshTokenService).revoke("refresh-token");
    }

    @Test
    void passwordResetShouldRevokeAllRefreshSessions() {
        User user = new User();
        user.setId(9L);
        user.setUsername("alice");
        user.setPhone("13800138000");
        when(userMapper.selectOne(any(Wrapper.class))).thenReturn(user);
        when(redisTemplate.opsForValue()).thenReturn(valueOperations);
        when(valueOperations.get(any())).thenReturn("123456");
        when(passwordEncoder.encode("new-secret")).thenReturn("new-hash");

        authService.resetPassword(
                new PasswordResetDTO(
                        "alice",
                        "13800138000",
                        "123456",
                        "new-secret",
                        "new-secret"
                )
        );

        verify(refreshTokenService).revokeAll(9L);
        verify(userMapper).updateById(user);
    }

    @Test
    void registerRejectsConfirmationAndUsernameLengthAndNormalizesBlankPhone() {
        assertThatThrownBy(() -> authService.register(
                new RegisterDTO("alice", "secret", "different", null)
        )).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> authService.register(
                new RegisterDTO("abc", "secret", "secret", null)
        )).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> authService.register(
                new RegisterDTO("x".repeat(21), "secret", "secret", null)
        )).isInstanceOf(IllegalArgumentException.class);

        when(userMapper.selectCount(any(Wrapper.class))).thenReturn(null);
        when(passwordEncoder.encode("secret")).thenReturn("hash");
        when(userMapper.insert(any(User.class))).thenAnswer(invocation -> {
            invocation.<User>getArgument(0).setId(1L);
            return 1;
        });
        authService.register(new RegisterDTO("valid", "secret", null, "  "));
        ArgumentCaptor<User> captor = ArgumentCaptor.forClass(User.class);
        verify(userMapper).insert(captor.capture());
        assertThat(captor.getValue().getPhone()).isNull();
    }

    @Test
    void loginFailureLockAndLegacyPasswordMigrationAreCovered() {
        when(redisTemplate.opsForValue()).thenReturn(valueOperations);
        when(valueOperations.get(any())).thenReturn(null);
        when(valueOperations.increment(any())).thenReturn(1L);
        when(userMapper.selectOne(any(Wrapper.class))).thenReturn(null);
        assertThatThrownBy(() -> authService.login(new LoginDTO("missing", "x", false)))
                .isInstanceOf(IllegalArgumentException.class);
        verify(redisTemplate).expire(any(), any());

        User blankPassword = new User();
        blankPassword.setUsername("blank");
        blankPassword.setPasswordHash(" ");
        when(userMapper.selectOne(any(Wrapper.class))).thenReturn(blankPassword);
        assertThatThrownBy(() -> authService.login(new LoginDTO("blank", "x", false)))
                .isInstanceOf(IllegalArgumentException.class);

        when(valueOperations.get(any())).thenReturn("5");
        assertThatThrownBy(() -> authService.login(new LoginDTO("locked", "x", false)))
                .isInstanceOf(IllegalArgumentException.class);
        when(valueOperations.get(any())).thenReturn("not-a-number");
        when(userMapper.selectOne(any(Wrapper.class))).thenReturn(null);
        assertThatThrownBy(() -> authService.login(new LoginDTO("reset-counter", "x", false)))
                .isInstanceOf(IllegalArgumentException.class);
        verify(redisTemplate).delete("auth:login-failure:reset-counter");

        User legacy = new User();
        legacy.setId(8L);
        legacy.setUsername("legacy");
        legacy.setPasswordHash("sha256:fcf730b6d95236ecd3c9fc2d92d7b6b2bb061514961aec041d6c7a7192f592e4");
        when(valueOperations.get(any())).thenReturn(null);
        when(userMapper.selectOne(any(Wrapper.class))).thenReturn(legacy);
        when(passwordEncoder.encode("secret123")).thenReturn("bcrypt");
        when(jwtService.generateToken(legacy)).thenReturn("token");
        authService.login(new LoginDTO("legacy", "secret123", false));
        assertThat(legacy.getPasswordHash()).isEqualTo("bcrypt");
        verify(userMapper).updateById(legacy);
    }

    @Test
    void refreshMissingUserRevokesRotatedToken() {
        when(refreshTokenService.rotate("old")).thenReturn(
                new AuthRefreshTokenService.RotatedRefreshToken(
                        99L, "rotated", java.time.LocalDateTime.now().plusDays(1)
                )
        );
        when(userMapper.selectById(99L)).thenReturn(null);
        assertThatThrownBy(() -> authService.refresh(new RefreshTokenDTO("old")))
                .isInstanceOf(AuthSessionException.class);
        verify(refreshTokenService).revoke("rotated");
    }

    @Test
    void passwordResetCodeAndResetValidationCoverSuccessAndFailures() {
        User user = new User();
        user.setId(9L);
        user.setUsername("alice");
        user.setPhone("13800138000");
        when(redisTemplate.opsForValue()).thenReturn(valueOperations);
        when(userMapper.selectOne(any(Wrapper.class))).thenReturn(user);
        when(redisTemplate.hasKey(any())).thenReturn(false);
        assertThat(authService.sendPasswordResetCode(
                new PasswordResetCodeDTO(" alice ", " 13800138000 ")
        ).devCode()).hasSize(6);
        verify(valueOperations, org.mockito.Mockito.times(2)).set(any(), any(), any());

        when(redisTemplate.hasKey(any())).thenReturn(true);
        assertThatThrownBy(() -> authService.sendPasswordResetCode(
                new PasswordResetCodeDTO("alice", "13800138000")
        )).isInstanceOf(IllegalArgumentException.class);

        assertThatThrownBy(() -> authService.resetPassword(
                new PasswordResetDTO("alice", "13800138000", "1", "new", "different")
        )).isInstanceOf(IllegalArgumentException.class);
        when(valueOperations.get(any())).thenReturn(null);
        assertThatThrownBy(() -> authService.resetPassword(
                new PasswordResetDTO("alice", "13800138000", "1", "new", "new")
        )).isInstanceOf(IllegalArgumentException.class);
        when(valueOperations.get(any())).thenReturn("123456");
        assertThatThrownBy(() -> authService.resetPassword(
                new PasswordResetDTO("alice", "13800138000", "000000", "new", "new")
        )).isInstanceOf(IllegalArgumentException.class);

        when(userMapper.selectOne(any(Wrapper.class))).thenReturn(null);
        assertThatThrownBy(() -> authService.sendPasswordResetCode(
                new PasswordResetCodeDTO("none", "13800138000")
        )).isInstanceOf(IllegalArgumentException.class);
    }
}

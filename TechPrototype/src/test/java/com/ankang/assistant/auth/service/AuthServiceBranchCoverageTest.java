package com.ankang.assistant.auth.service;

import com.ankang.assistant.auth.dto.LoginDTO;
import com.ankang.assistant.auth.dto.PasswordResetDTO;
import com.ankang.assistant.auth.dto.RegisterDTO;
import com.ankang.assistant.config.JwtService;
import com.ankang.assistant.user.entity.User;
import com.ankang.assistant.user.mapper.UserMapper;
import com.baomidou.mybatisplus.core.conditions.Wrapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.security.crypto.password.PasswordEncoder;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AuthServiceBranchCoverageTest {

    @Mock UserMapper userMapper;
    @Mock PasswordEncoder passwordEncoder;
    @Mock JwtService jwtService;
    @Mock StringRedisTemplate redisTemplate;
    @Mock AuthRefreshTokenService refreshTokenService;
    @Mock ValueOperations<String, String> values;

    private AuthService service;

    @BeforeEach
    void setUp() {
        service = new AuthService(userMapper, passwordEncoder, jwtService,
                redisTemplate, refreshTokenService);
    }

    @Test
    void registrationCoversBlankConfirmationNullPhoneAndNonzeroCountAlternatives() {
        when(userMapper.selectCount(any(Wrapper.class))).thenReturn(0L);
        when(passwordEncoder.encode("secret")).thenReturn("hash");
        when(userMapper.insert(any(User.class))).thenAnswer(invocation -> {
            invocation.<User>getArgument(0).setId(1L);
            return 1;
        });

        assertThat(service.register(new RegisterDTO("valid", "secret", " ", null)).id())
                .isEqualTo(1L);
    }

    @Test
    void loginCoversRoleBranchesAndFailureCounterAlternatives() {
        when(redisTemplate.opsForValue()).thenReturn(values);
        when(values.get(any())).thenReturn("4");

        User blankRole = user("blank-role", "encoded", " ");
        when(userMapper.selectOne(any(Wrapper.class))).thenReturn(blankRole);
        when(passwordEncoder.matches("secret", "encoded")).thenReturn(true);
        when(jwtService.generateToken(blankRole)).thenReturn("token");
        assertThat(service.login(new LoginDTO("blank-role", "secret", false))
                .user().role()).isEqualTo("PATIENT");

        User admin = user("admin", "encoded-admin", "ADMIN");
        when(userMapper.selectOne(any(Wrapper.class))).thenReturn(admin);
        when(passwordEncoder.matches("secret", "encoded-admin")).thenReturn(true);
        when(jwtService.generateToken(admin)).thenReturn("token");
        assertThat(service.login(new LoginDTO("admin", "secret", false))
                .user().role()).isEqualTo("ADMIN");

        when(userMapper.selectOne(any(Wrapper.class))).thenReturn(null);
        when(values.increment(any())).thenReturn(null, 2L);
        assertThatThrownBy(() -> service.login(new LoginDTO("missing-one", "secret", false)))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> service.login(new LoginDTO("missing-two", "secret", false)))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void loginCoversNullStoredHashAndUnmatchedLegacyHash() {
        when(redisTemplate.opsForValue()).thenReturn(values);
        when(values.get(any())).thenReturn(null);
        when(values.increment(any())).thenReturn(2L);

        User noPassword = user("none", null, null);
        when(userMapper.selectOne(any(Wrapper.class))).thenReturn(noPassword);
        assertThatThrownBy(() -> service.login(new LoginDTO("none", "secret", false)))
                .isInstanceOf(IllegalArgumentException.class);

        User legacy = user("legacy", "sha256:" + "0".repeat(64), null);
        when(userMapper.selectOne(any(Wrapper.class))).thenReturn(legacy);
        assertThatThrownBy(() -> service.login(new LoginDTO("legacy", "wrong", false)))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void resetPasswordAcceptsNullAndBlankConfirmation() {
        when(redisTemplate.opsForValue()).thenReturn(values);
        when(values.get(any())).thenReturn("123456");
        when(passwordEncoder.encode("new-secret")).thenReturn("new-hash");

        User first = user("alice", "old", null);
        first.setPhone("13800138000");
        first.setId(1L);
        User second = user("bob", "old", null);
        second.setPhone("13900139000");
        second.setId(2L);
        when(userMapper.selectOne(any(Wrapper.class))).thenReturn(first, second);

        service.resetPassword(new PasswordResetDTO(
                "alice", "13800138000", "123456", "new-secret", null));
        service.resetPassword(new PasswordResetDTO(
                "bob", "13900139000", "123456", "new-secret", " "));
        assertThat(first.getPasswordHash()).isEqualTo("new-hash");
        assertThat(second.getPasswordHash()).isEqualTo("new-hash");
    }

    private User user(String username, String passwordHash, String role) {
        User user = new User();
        user.setId(7L);
        user.setUsername(username);
        user.setPasswordHash(passwordHash);
        user.setRole(role);
        return user;
    }
}

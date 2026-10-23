package com.ankang.assistant.auth.service;

import com.ankang.assistant.auth.dto.LoginDTO;
import com.ankang.assistant.auth.dto.LogoutDTO;
import com.ankang.assistant.auth.dto.PasswordResetCodeDTO;
import com.ankang.assistant.auth.dto.PasswordResetDTO;
import com.ankang.assistant.auth.dto.RefreshTokenDTO;
import com.ankang.assistant.auth.dto.RegisterDTO;
import com.ankang.assistant.auth.vo.AuthTokenVO;
import com.ankang.assistant.auth.vo.LoginVO;
import com.ankang.assistant.auth.vo.PasswordResetCodeVO;
import com.ankang.assistant.auth.vo.RegisterVO;
import com.ankang.assistant.config.JwtService;
import com.ankang.assistant.user.entity.User;
import com.ankang.assistant.user.mapper.UserMapper;
import com.ankang.assistant.user.vo.UserProfileVO;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Duration;
import java.util.HexFormat;

@Service
public class AuthService {

    private static final String PASSWORD_HASH_PREFIX = "sha256:";
    private static final Duration RESET_CODE_TTL = Duration.ofMinutes(5);
    private static final Duration RESET_CODE_SEND_INTERVAL = Duration.ofSeconds(60);
    private static final Duration LOGIN_FAILURE_WINDOW = Duration.ofMinutes(10);
    private static final int MAX_LOGIN_FAILURES = 5;
    private static final int USERNAME_MIN_LENGTH = 4;
    private static final int USERNAME_MAX_LENGTH = 20;
    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    private final UserMapper userMapper;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final StringRedisTemplate redisTemplate;
    private final AuthRefreshTokenService refreshTokenService;

    public AuthService(UserMapper userMapper, PasswordEncoder passwordEncoder, JwtService jwtService,
                       StringRedisTemplate redisTemplate, AuthRefreshTokenService refreshTokenService) {
        this.userMapper = userMapper;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.redisTemplate = redisTemplate;
        this.refreshTokenService = refreshTokenService;
    }

    @Transactional
    public RegisterVO register(RegisterDTO dto) {
        if (dto.confirmPassword() != null && !dto.confirmPassword().isBlank()
                && !dto.password().equals(dto.confirmPassword())) {
            throw new IllegalArgumentException("两次输入的密码不一致");
        }

        String username = dto.username().trim();
        validateUsername(username);
        if (existsByUsername(username)) {
            throw new IllegalArgumentException("用户名已存在");
        }

        User user = new User();
        user.setUsername(username);
        user.setPasswordHash(passwordEncoder.encode(dto.password()));
        user.setNickname(username);
        user.setPhone(blankToNull(dto.phone()));
        userMapper.insert(user);
        return new RegisterVO(user.getId(), user.getUsername());
    }

    @Transactional
    public LoginVO login(LoginDTO dto) {
        String username = dto.username().trim();
        String failureKey = loginFailureKey(username);
        assertLoginAllowed(failureKey);

        User user = userMapper.selectOne(new LambdaQueryWrapper<User>()
                .eq(User::getUsername, username)
                .last("limit 1"));
        if (user == null) {
            recordLoginFailure(failureKey);
            throw new IllegalArgumentException("用户不存在");
        }
        if (!matchesPassword(dto.password(), user)) {
            recordLoginFailure(failureKey);
            throw new IllegalArgumentException("账号或密码错误");
        }

        redisTemplate.delete(failureKey);
        AuthRefreshTokenService.IssuedRefreshToken refreshToken = dto.shouldKeepSignedIn()
                ? refreshTokenService.issue(user.getId())
                : null;
        return new LoginVO(
                jwtService.generateToken(user),
                refreshToken == null ? null : refreshToken.token(),
                jwtService.getExpirationSeconds(),
                refreshToken == null ? null : refreshToken.expiresAt(),
                toProfile(user)
        );
    }

    @Transactional
    public AuthTokenVO refresh(RefreshTokenDTO dto) {
        AuthRefreshTokenService.RotatedRefreshToken rotated =
                refreshTokenService.rotate(dto.refreshToken());
        User user = userMapper.selectById(rotated.userId());
        if (user == null) {
            refreshTokenService.revoke(rotated.token());
            throw new AuthSessionException("用户不存在，请重新登录");
        }
        return new AuthTokenVO(
                jwtService.generateToken(user),
                rotated.token(),
                jwtService.getExpirationSeconds(),
                rotated.expiresAt()
        );
    }

    public void logout(LogoutDTO dto) {
        refreshTokenService.revoke(dto.refreshToken());
    }

    public PasswordResetCodeVO sendPasswordResetCode(PasswordResetCodeDTO dto) {
        User user = findUserByUsernameAndPhone(dto.username(), dto.phone());
        String sendLimitKey = resetCodeSendLimitKey(user.getPhone());
        if (Boolean.TRUE.equals(redisTemplate.hasKey(sendLimitKey))) {
            throw new IllegalArgumentException("验证码发送过于频繁，请稍后再试");
        }

        String code = "%06d".formatted(SECURE_RANDOM.nextInt(1_000_000));
        redisTemplate.opsForValue().set(resetKey(user.getUsername(), user.getPhone()), code, RESET_CODE_TTL);
        redisTemplate.opsForValue().set(sendLimitKey, "1", RESET_CODE_SEND_INTERVAL);
        return new PasswordResetCodeVO("验证码已发送", code, RESET_CODE_TTL.toSeconds());
    }

    @Transactional
    public void resetPassword(PasswordResetDTO dto) {
        if (dto.confirmPassword() != null && !dto.confirmPassword().isBlank()
                && !dto.newPassword().equals(dto.confirmPassword())) {
            throw new IllegalArgumentException("两次输入的新密码不一致");
        }

        User user = findUserByUsernameAndPhone(dto.username(), dto.phone());
        String key = resetKey(user.getUsername(), user.getPhone());
        String code = redisTemplate.opsForValue().get(key);
        if (code == null) {
            throw new IllegalArgumentException("请先获取验证码或验证码已过期");
        }
        if (!code.equals(dto.code().trim())) {
            throw new IllegalArgumentException("验证码错误");
        }

        user.setPasswordHash(passwordEncoder.encode(dto.newPassword()));
        userMapper.updateById(user);
        redisTemplate.delete(key);
        refreshTokenService.revokeAll(user.getId());
    }

    private boolean existsByUsername(String username) {
        Long count = userMapper.selectCount(new LambdaQueryWrapper<User>()
                .eq(User::getUsername, username));
        return count != null && count > 0;
    }

    private void validateUsername(String username) {
        if (username.length() < USERNAME_MIN_LENGTH || username.length() > USERNAME_MAX_LENGTH) {
            throw new IllegalArgumentException("账号长度需为 4-20 个字符");
        }
    }

    private String hashPassword(String password) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hashed = digest.digest(password.getBytes(StandardCharsets.UTF_8));
            return PASSWORD_HASH_PREFIX + HexFormat.of().formatHex(hashed);
        } catch (NoSuchAlgorithmException ex) {
            throw new IllegalStateException("密码摘要算法不可用", ex);
        }
    }

    private UserProfileVO toProfile(User user) {
        return new UserProfileVO(
                user.getId(),
                user.getUsername(),
                user.getNickname(),
                user.getAge(),
                user.getGender(),
                user.getPhone(),
                user.getEmail(),
                user.getAvatarUrl(),
                user.getRole() == null || user.getRole().isBlank() ? "PATIENT" : user.getRole()
        );
    }

    private String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }

    private User findUserByUsernameAndPhone(String username, String phone) {
        User user = userMapper.selectOne(new LambdaQueryWrapper<User>()
                .eq(User::getUsername, username.trim())
                .eq(User::getPhone, phone.trim())
                .last("limit 1"));
        if (user == null) {
            throw new IllegalArgumentException("账号或手机号不匹配");
        }
        return user;
    }

    private String resetKey(String username, String phone) {
        return "auth:password-reset:" + username.trim() + ":" + phone.trim();
    }

    private String resetCodeSendLimitKey(String phone) {
        return "auth:password-reset-send-limit:" + phone.trim();
    }

    private String loginFailureKey(String username) {
        return "auth:login-failure:" + username.trim();
    }

    private void assertLoginAllowed(String key) {
        String count = redisTemplate.opsForValue().get(key);
        if (count == null) {
            return;
        }
        try {
            if (Integer.parseInt(count) < MAX_LOGIN_FAILURES) {
                return;
            }
        } catch (NumberFormatException ex) {
            redisTemplate.delete(key);
            return;
        }
        throw new IllegalArgumentException("登录失败次数过多，请稍后再试");
    }

    private void recordLoginFailure(String key) {
        Long count = redisTemplate.opsForValue().increment(key);
        if (count != null && count == 1L) {
            redisTemplate.expire(key, LOGIN_FAILURE_WINDOW);
        }
    }

    private boolean matchesPassword(String rawPassword, User user) {
        String storedPassword = user.getPasswordHash();
        if (storedPassword == null || storedPassword.isBlank()) {
            return false;
        }
        if (storedPassword.startsWith(PASSWORD_HASH_PREFIX)) {
            boolean matched = hashPassword(rawPassword).equals(storedPassword);
            if (matched) {
                user.setPasswordHash(passwordEncoder.encode(rawPassword));
                userMapper.updateById(user);
            }
            return matched;
        }
        return passwordEncoder.matches(rawPassword, storedPassword);
    }
}

package com.ankang.assistant.auth.controller;

import com.ankang.assistant.auth.dto.LoginDTO;
import com.ankang.assistant.auth.dto.LogoutDTO;
import com.ankang.assistant.auth.dto.PasswordResetCodeDTO;
import com.ankang.assistant.auth.dto.PasswordResetDTO;
import com.ankang.assistant.auth.dto.RegisterDTO;
import com.ankang.assistant.auth.dto.RefreshTokenDTO;
import com.ankang.assistant.auth.vo.AuthTokenVO;
import com.ankang.assistant.auth.service.AuthService;
import com.ankang.assistant.auth.vo.LoginVO;
import com.ankang.assistant.auth.vo.PasswordResetCodeVO;
import com.ankang.assistant.auth.vo.RegisterVO;
import com.ankang.assistant.common.Result;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "认证模块")
@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @Operation(summary = "用户注册")
    @PostMapping("/register")
    public Result<RegisterVO> register(@Valid @RequestBody RegisterDTO dto) {
        return Result.success(authService.register(dto));
    }

    @Operation(summary = "用户登录")
    @PostMapping("/login")
    public Result<LoginVO> login(@Valid @RequestBody LoginDTO dto) {
        return Result.success(authService.login(dto));
    }

    @Operation(summary = "刷新登录状态")
    @PostMapping("/refresh")
    public Result<AuthTokenVO> refresh(@Valid @RequestBody RefreshTokenDTO dto) {
        return Result.success(authService.refresh(dto));
    }

    @Operation(summary = "退出并撤销刷新令牌")
    @PostMapping("/logout")
    public Result<Void> logout(@Valid @RequestBody LogoutDTO dto) {
        authService.logout(dto);
        return Result.success();
    }

    @Operation(summary = "发送重置密码验证码")
    @PostMapping("/password-reset/code")
    public Result<PasswordResetCodeVO> sendPasswordResetCode(@Valid @RequestBody PasswordResetCodeDTO dto) {
        return Result.success(authService.sendPasswordResetCode(dto));
    }

    @Operation(summary = "通过验证码重置密码")
    @PostMapping("/password-reset")
    public Result<Void> resetPassword(@Valid @RequestBody PasswordResetDTO dto) {
        authService.resetPassword(dto);
        return Result.success();
    }
}

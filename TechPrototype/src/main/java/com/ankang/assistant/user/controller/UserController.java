package com.ankang.assistant.user.controller;

import com.ankang.assistant.common.Result;
import com.ankang.assistant.user.dto.HealthGoalUpdateDTO;
import com.ankang.assistant.user.dto.HealthProfileUpdateDTO;
import com.ankang.assistant.user.dto.PasswordChangeDTO;
import com.ankang.assistant.user.dto.UserProfileUpdateDTO;
import com.ankang.assistant.user.dto.UserSettingUpdateDTO;
import com.ankang.assistant.user.service.UserService;
import com.ankang.assistant.user.vo.HealthGoalVO;
import com.ankang.assistant.user.vo.HealthGoalProgressVO;
import com.ankang.assistant.user.vo.HealthProfileVO;
import com.ankang.assistant.user.vo.UserProfileVO;
import com.ankang.assistant.user.vo.UserSettingVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "用户模块")
@RestController
@RequestMapping("/api")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @Operation(summary = "获取用户资料")
    @GetMapping({"/user/profile", "/users/me"})
    public Result<UserProfileVO> getProfile() {
        return Result.success(userService.getProfile());
    }

    @Operation(summary = "更新用户资料")
    @PutMapping("/user/profile")
    public Result<UserProfileVO> updateProfile(@Valid @RequestBody UserProfileUpdateDTO dto) {
        return Result.success(userService.updateProfile(dto));
    }

    @Operation(summary = "修改登录密码")
    @PutMapping({"/user/password", "/user/profile/password"})
    public Result<Void> changePassword(@RequestBody PasswordChangeDTO dto) {
        userService.changePassword(dto);
        return Result.success();
    }

    @Operation(summary = "获取健康档案")
    @GetMapping({"/user/health-profile", "/profile/health"})
    public Result<HealthProfileVO> getHealthProfile() {
        return Result.success(userService.getHealthProfile());
    }

    @Operation(summary = "更新健康档案")
    @PutMapping({"/user/health-profile", "/profile/health"})
    public Result<HealthProfileVO> updateHealthProfile(@RequestBody HealthProfileUpdateDTO dto) {
        return Result.success(userService.updateHealthProfile(dto));
    }

    @Operation(summary = "获取健康目标")
    @GetMapping({"/user/health-goals", "/profile/goals"})
    public Result<HealthGoalVO> getHealthGoal() {
        return Result.success(userService.getHealthGoal());
    }

    @Operation(summary = "获取健康目标自动进度")
    @GetMapping({"/user/health-goals/progress", "/profile/goals/progress"})
    public Result<HealthGoalProgressVO> getHealthGoalProgress() {
        return Result.success(userService.getHealthGoalProgress());
    }

    @Operation(summary = "更新健康目标")
    @PutMapping({"/user/health-goals", "/profile/goals"})
    public Result<HealthGoalVO> updateHealthGoal(@RequestBody HealthGoalUpdateDTO dto) {
        return Result.success(userService.updateHealthGoal(dto));
    }

    @Operation(summary = "获取用户设置")
    @GetMapping({"/user/settings", "/profile/settings"})
    public Result<UserSettingVO> getSettings() {
        return Result.success(userService.getSettings());
    }

    @Operation(summary = "更新用户设置")
    @PutMapping({"/user/settings", "/profile/settings"})
    public Result<UserSettingVO> updateSettings(@RequestBody UserSettingUpdateDTO dto) {
        return Result.success(userService.updateSettings(dto));
    }
}

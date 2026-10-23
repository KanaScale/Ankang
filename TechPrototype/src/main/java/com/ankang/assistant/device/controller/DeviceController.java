package com.ankang.assistant.device.controller;

import com.ankang.assistant.common.Result;
import com.ankang.assistant.device.dto.DeviceCustomSyncDTO;
import com.ankang.assistant.device.dto.DeviceSignalDTO;
import com.ankang.assistant.device.service.DeviceService;
import com.ankang.assistant.device.vo.DeviceSyncVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "设备同步模块")
@RestController
@RequestMapping("/api/devices")
public class DeviceController {

    private final DeviceService deviceService;

    public DeviceController(DeviceService deviceService) {
        this.deviceService = deviceService;
    }

    @Operation(summary = "获取当前模拟设备状态")
    @GetMapping("/current")
    public Result<DeviceSyncVO> currentDevice() {
        return Result.success(deviceService.getCurrentDevice());
    }

    @Operation(summary = "模拟同步设备数据")
    @PostMapping("/sync/mock")
    public Result<DeviceSyncVO> mockSync() {
        return Result.success(deviceService.mockSync());
    }

    @Operation(summary = "提交自定义设备同步数据")
    @PostMapping("/sync/custom")
    public Result<DeviceSyncVO> customSync(@Valid @RequestBody DeviceCustomSyncDTO dto) {
        return Result.success(deviceService.customSync(dto));
    }

    @Operation(summary = "发送模拟设备信号")
    @PostMapping("/signal")
    public Result<DeviceSyncVO> sendSignal(@Valid @RequestBody(required = false) DeviceSignalDTO dto) {
        return Result.success(deviceService.sendSignal(dto));
    }
}

package com.ankang.assistant.emergency.controller;

import com.ankang.assistant.common.Result;
import com.ankang.assistant.emergency.dto.EmergencyContactSaveDTO;
import com.ankang.assistant.emergency.dto.DispatchResultsDTO;
import com.ankang.assistant.emergency.dto.SosCreateDTO;
import com.ankang.assistant.emergency.service.EmergencyService;
import com.ankang.assistant.emergency.service.NearbyHospitalService;
import com.ankang.assistant.emergency.vo.EmergencyContactVO;
import com.ankang.assistant.emergency.vo.EmergencyEventVO;
import com.ankang.assistant.emergency.vo.NearbyHospitalVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@Tag(name = "紧急救援模块")
@RestController
@RequestMapping("/api/emergency")
public class EmergencyController {

    private final EmergencyService emergencyService;
    private final NearbyHospitalService nearbyHospitalService;

    public EmergencyController(EmergencyService emergencyService, NearbyHospitalService nearbyHospitalService) {
        this.emergencyService = emergencyService;
        this.nearbyHospitalService = nearbyHospitalService;
    }

    @Operation(summary = "紧急联系人列表")
    @GetMapping("/contacts")
    public Result<List<EmergencyContactVO>> listContacts() {
        return Result.success(emergencyService.listContacts());
    }

    @Operation(summary = "新增紧急联系人")
    @PostMapping("/contacts")
    public Result<EmergencyContactVO> createContact(@Valid @RequestBody EmergencyContactSaveDTO dto) {
        return Result.success(emergencyService.createContact(dto));
    }

    @Operation(summary = "更新紧急联系人")
    @PutMapping("/contacts/{id}")
    public Result<EmergencyContactVO> updateContact(@PathVariable Long id, @Valid @RequestBody EmergencyContactSaveDTO dto) {
        return Result.success(emergencyService.updateContact(id, dto));
    }

    @Operation(summary = "删除紧急联系人")
    @DeleteMapping("/contacts/{id}")
    public Result<Void> deleteContact(@PathVariable Long id) {
        emergencyService.deleteContact(id);
        return Result.success();
    }

    @Operation(summary = "发起 SOS 求助")
    @PostMapping("/sos")
    public Result<EmergencyEventVO> createSosEvent(@Valid @RequestBody SosCreateDTO dto) {
        return Result.success(emergencyService.createSosEvent(dto));
    }

    @Operation(summary = "上报 SOS 逐联系人逐渠道执行结果")
    @PutMapping("/events/{clientEventId}/dispatch-results")
    public Result<EmergencyEventVO> updateDispatchResults(
            @PathVariable String clientEventId,
            @Valid @RequestBody DispatchResultsDTO dto
    ) {
        return Result.success(emergencyService.updateDispatchResults(clientEventId, dto));
    }

    @Operation(summary = "SOS 历史记录")
    @GetMapping("/events")
    public Result<List<EmergencyEventVO>> listEvents() {
        return Result.success(emergencyService.listEvents());
    }

    @Operation(summary = "根据 WGS84 坐标获取附近医院")
    @GetMapping("/nearby-hospitals")
    public Result<NearbyHospitalVO> nearbyHospitals(
            @RequestParam double latitude,
            @RequestParam double longitude,
            @RequestParam(defaultValue = "5000") int radiusMeters
    ) {
        return Result.success(nearbyHospitalService.findNearby(latitude, longitude, radiusMeters));
    }
}

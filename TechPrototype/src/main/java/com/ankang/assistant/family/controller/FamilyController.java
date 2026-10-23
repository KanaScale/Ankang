package com.ankang.assistant.family.controller;

import com.ankang.assistant.agent.dto.AgentChatDTO;
import com.ankang.assistant.agent.service.AgentService;
import com.ankang.assistant.agent.vo.AgentReplyVO;
import com.ankang.assistant.common.Result;
import com.ankang.assistant.config.SecurityUtils;
import com.ankang.assistant.emergency.service.EmergencyService;
import com.ankang.assistant.emergency.vo.EmergencyEventVO;
import com.ankang.assistant.family.dto.BindPatientRequest;
import com.ankang.assistant.family.dto.CreateInviteRequest;
import com.ankang.assistant.family.service.FamilyPermissionService;
import com.ankang.assistant.family.service.FamilyService;
import com.ankang.assistant.family.vo.BoundPatientVO;
import com.ankang.assistant.family.vo.FamilyHealthSummaryVO;
import com.ankang.assistant.family.vo.FamilyInviteVO;
import com.ankang.assistant.health.service.HealthService;
import com.ankang.assistant.health.vo.HealthRecordVO;
import com.ankang.assistant.health.vo.HealthTrendVO;
import com.ankang.assistant.health.vo.PageVO;
import com.ankang.assistant.reminder.service.ReminderService;
import com.ankang.assistant.reminder.vo.ReminderVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.List;

@Tag(name = "家庭照护模块")
@RestController
@RequestMapping("/api/family")
public class FamilyController {

    private final FamilyService familyService;
    private final FamilyPermissionService permissionService;
    private final HealthService healthService;
    private final ReminderService reminderService;
    private final EmergencyService emergencyService;
    private final AgentService agentService;

    public FamilyController(
            FamilyService familyService,
            FamilyPermissionService permissionService,
            HealthService healthService,
            ReminderService reminderService,
            EmergencyService emergencyService,
            AgentService agentService
    ) {
        this.familyService = familyService;
        this.permissionService = permissionService;
        this.healthService = healthService;
        this.reminderService = reminderService;
        this.emergencyService = emergencyService;
        this.agentService = agentService;
    }

    @Operation(summary = "生成家属绑定码")
    @PostMapping("/invite")
    public Result<FamilyInviteVO> createInvite(@RequestBody(required = false) CreateInviteRequest request) {
        return Result.success(familyService.createInvite(SecurityUtils.currentUserId()));
    }

    @Operation(summary = "通过绑定码绑定被照护者")
    @PostMapping("/bind")
    public Result<BoundPatientVO> bindPatient(@Valid @RequestBody BindPatientRequest request) {
        return Result.success(familyService.bindPatient(SecurityUtils.currentUserId(), request));
    }

    @Operation(summary = "查询当前家属绑定的被照护者列表")
    @GetMapping("/patients")
    public Result<List<BoundPatientVO>> listPatients() {
        return Result.success(familyService.listBoundPatients(SecurityUtils.currentUserId()));
    }

    @Operation(summary = "解除家庭照护绑定")
    @DeleteMapping("/patients/{patientId}")
    public Result<Void> removePatient(@PathVariable Long patientId) {
        familyService.removeRelation(SecurityUtils.currentUserId(), patientId);
        return Result.success();
    }

    @Operation(summary = "家属查看被照护者健康摘要")
    @GetMapping("/patients/{patientId}/summary")
    public Result<FamilyHealthSummaryVO> getSummary(@PathVariable Long patientId) {
        Long caregiverUserId = SecurityUtils.currentUserId();
        permissionService.checkCaregiverAccess(caregiverUserId, patientId, FamilyService.VIEW_HEALTH);
        return Result.success(familyService.buildFamilyHealthSummary(patientId));
    }

    @Operation(summary = "家属查看被照护者健康记录")
    @GetMapping("/patients/{patientId}/records")
    public Result<PageVO<HealthRecordVO>> getRecords(
            @PathVariable Long patientId,
            @RequestParam(required = false) String type,
            @RequestParam(required = false) @DateTimeFormat(pattern = "yyyy-MM-dd") LocalDate startDate,
            @RequestParam(required = false) @DateTimeFormat(pattern = "yyyy-MM-dd") LocalDate endDate,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        Long caregiverUserId = SecurityUtils.currentUserId();
        permissionService.checkCaregiverAccess(caregiverUserId, patientId, FamilyService.VIEW_HEALTH);
        return Result.success(healthService.getRecordsByUserId(patientId, type, startDate, endDate, page, size));
    }

    @Operation(summary = "家属查看被照护者健康趋势")
    @GetMapping("/patients/{patientId}/trend")
    public Result<HealthTrendVO> getTrend(
            @PathVariable Long patientId,
            @RequestParam String type,
            @RequestParam(required = false) Integer days,
            @RequestParam(required = false) String range
    ) {
        Long caregiverUserId = SecurityUtils.currentUserId();
        permissionService.checkCaregiverAccess(caregiverUserId, patientId, FamilyService.VIEW_HEALTH);
        return Result.success(healthService.getTrendByUserId(patientId, type, days, range));
    }

    @Operation(summary = "家属查看被照护者提醒")
    @GetMapping("/patients/{patientId}/reminders")
    public Result<List<ReminderVO>> getReminders(@PathVariable Long patientId) {
        Long caregiverUserId = SecurityUtils.currentUserId();
        permissionService.checkCaregiverAccess(caregiverUserId, patientId, FamilyService.VIEW_REMINDER);
        return Result.success(reminderService.listRemindersByUserId(patientId));
    }

    @Operation(summary = "家属查看被照护者 SOS 记录")
    @GetMapping("/patients/{patientId}/sos-events")
    public Result<List<EmergencyEventVO>> getSosEvents(@PathVariable Long patientId) {
        Long caregiverUserId = SecurityUtils.currentUserId();
        permissionService.checkCaregiverAccess(caregiverUserId, patientId, FamilyService.VIEW_SOS);
        return Result.success(emergencyService.listEventsByUserId(patientId));
    }

    @Operation(summary = "家属基于被照护者健康上下文咨询 Agent")
    @PostMapping("/patients/{patientId}/agent/chat")
    public Result<AgentReplyVO> familyAgentChat(
            @PathVariable Long patientId,
            @Valid @RequestBody AgentChatDTO request
    ) {
        Long caregiverUserId = SecurityUtils.currentUserId();
        permissionService.checkCaregiverAccess(caregiverUserId, patientId, FamilyService.ASK_AGENT);
        return Result.success(agentService.chatForCaregiver(caregiverUserId, patientId, request));
    }
}

package com.ankang.assistant.family.controller;

import com.ankang.assistant.agent.service.AgentService;
import com.ankang.assistant.config.JwtService;
import com.ankang.assistant.emergency.service.EmergencyService;
import com.ankang.assistant.family.service.FamilyPermissionService;
import com.ankang.assistant.family.service.FamilyService;
import com.ankang.assistant.health.service.HealthService;
import com.ankang.assistant.health.vo.HealthRecordVO;
import com.ankang.assistant.health.vo.HealthSummaryVO;
import com.ankang.assistant.health.vo.PageVO;
import com.ankang.assistant.reminder.service.ReminderService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;

import java.lang.reflect.Method;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class FamilyHealthReadOnlyTest {

    @AfterEach
    void clearSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void caregiverReadsPatientSummaryAfterPermissionCheck() {
        authenticateAs(7L);
        FamilyPermissionService permissionService = mock(FamilyPermissionService.class);
        FamilyService familyService = mock(FamilyService.class);
        when(familyService.buildFamilyHealthSummary(1L)).thenReturn(new com.ankang.assistant.family.vo.FamilyHealthSummaryVO(
                1L,
                "张三",
                null,
                new HealthSummaryVO(90, "整体状态良好", List.of())
        ));

        FamilyController controller = controller(familyService, permissionService, mock(HealthService.class));

        var result = controller.getSummary(1L);

        assertThat(result.getData().summary().healthScore()).isEqualTo(90);
        verify(permissionService).checkCaregiverAccess(7L, 1L, FamilyService.VIEW_HEALTH);
        verify(familyService).buildFamilyHealthSummary(1L);
    }

    @Test
    void caregiverReadsPatientHealthRecordsThroughPatientUserId() {
        authenticateAs(7L);
        FamilyPermissionService permissionService = mock(FamilyPermissionService.class);
        HealthService healthService = mock(HealthService.class);
        PageVO<HealthRecordVO> page = new PageVO<>(List.of(new HealthRecordVO(
                10L,
                "blood_pressure",
                new BigDecimal("130"),
                new BigDecimal("130"),
                new BigDecimal("82"),
                130,
                82,
                "mmHg",
                "normal",
                "manual",
                null,
                LocalDateTime.of(2026, 7, 24, 8, 0)
        )), 1, 1, 20);
        when(healthService.getRecordsByUserId(1L, "blood_pressure", null, null, 1, 20)).thenReturn(page);

        FamilyController controller = controller(mock(FamilyService.class), permissionService, healthService);

        var result = controller.getRecords(1L, "blood_pressure", null, null, 1, 20);

        assertThat(result.getData().items()).hasSize(1);
        verify(permissionService).checkCaregiverAccess(7L, 1L, FamilyService.VIEW_HEALTH);
        verify(healthService).getRecordsByUserId(1L, "blood_pressure", null, null, 1, 20);
    }

    @Test
    void familyControllerDoesNotExposeHealthRecordWriteEndpoint() {
        boolean hasFamilyRecordWrite = Arrays.stream(FamilyController.class.getDeclaredMethods())
                .filter(method -> hasMutationMapping(method))
                .flatMap(method -> Arrays.stream(mappingValues(method)))
                .anyMatch(path -> path.contains("records"));

        assertThat(hasFamilyRecordWrite).isFalse();
    }

    private boolean hasMutationMapping(Method method) {
        return method.isAnnotationPresent(PostMapping.class)
                || method.isAnnotationPresent(PutMapping.class)
                || method.isAnnotationPresent(DeleteMapping.class);
    }

    private String[] mappingValues(Method method) {
        PostMapping postMapping = method.getAnnotation(PostMapping.class);
        if (postMapping != null) return postMapping.value();
        PutMapping putMapping = method.getAnnotation(PutMapping.class);
        if (putMapping != null) return putMapping.value();
        DeleteMapping deleteMapping = method.getAnnotation(DeleteMapping.class);
        if (deleteMapping != null) return deleteMapping.value();
        return new String[0];
    }

    private FamilyController controller(
            FamilyService familyService,
            FamilyPermissionService permissionService,
            HealthService healthService
    ) {
        return new FamilyController(
                familyService,
                permissionService,
                healthService,
                mock(ReminderService.class),
                mock(EmergencyService.class),
                mock(AgentService.class)
        );
    }

    private void authenticateAs(Long userId) {
        JwtService.JwtUser principal = new JwtService.JwtUser(userId, "family-health-test");
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(principal, null, List.of())
        );
    }
}

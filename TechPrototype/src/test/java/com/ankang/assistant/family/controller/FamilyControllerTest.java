package com.ankang.assistant.family.controller;

import com.ankang.assistant.agent.service.AgentService;
import com.ankang.assistant.config.JwtService;
import com.ankang.assistant.emergency.service.EmergencyService;
import com.ankang.assistant.family.dto.BindPatientRequest;
import com.ankang.assistant.family.service.FamilyPermissionService;
import com.ankang.assistant.family.service.FamilyService;
import com.ankang.assistant.family.vo.BoundPatientVO;
import com.ankang.assistant.family.vo.FamilyInviteVO;
import com.ankang.assistant.health.service.HealthService;
import com.ankang.assistant.reminder.service.ReminderService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class FamilyControllerTest {

    @AfterEach
    void clearSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void createInviteUsesCurrentUserAsPatient() {
        authenticateAs(1L);
        FamilyService familyService = mock(FamilyService.class);
        LocalDateTime expireAt = LocalDateTime.of(2026, 7, 24, 20, 30);
        when(familyService.createInvite(1L)).thenReturn(new FamilyInviteVO("A7K92Q", expireAt));

        var result = controller(familyService).createInvite(null);

        assertThat(result.getData().inviteCode()).isEqualTo("A7K92Q");
        assertThat(result.getData().expireAt()).isEqualTo(expireAt);
        verify(familyService).createInvite(1L);
    }

    @Test
    void bindPatientUsesCurrentUserAsCaregiver() {
        authenticateAs(7L);
        FamilyService familyService = mock(FamilyService.class);
        BindPatientRequest request = new BindPatientRequest("A7K92Q", "son");
        BoundPatientVO patient = new BoundPatientVO(
                1L, "张三", "son", "ACTIVE", "medium", null,
                List.of(FamilyService.VIEW_HEALTH, FamilyService.ASK_AGENT)
        );
        when(familyService.bindPatient(7L, request)).thenReturn(patient);

        var result = controller(familyService).bindPatient(request);

        assertThat(result.getData().patientUserId()).isEqualTo(1L);
        assertThat(result.getData().patientName()).isEqualTo("张三");
        verify(familyService).bindPatient(7L, request);
    }

    @Test
    void listBoundPatientsUsesCurrentCaregiver() {
        authenticateAs(7L);
        FamilyService familyService = mock(FamilyService.class);
        when(familyService.listBoundPatients(7L)).thenReturn(List.of(new BoundPatientVO(
                1L, "张三", "father", "ACTIVE", "low", null, List.of(FamilyService.VIEW_HEALTH)
        )));

        var result = controller(familyService).listPatients();

        assertThat(result.getData()).hasSize(1);
        assertThat(result.getData().get(0).patientUserId()).isEqualTo(1L);
        verify(familyService).listBoundPatients(7L);
    }

    private FamilyController controller(FamilyService familyService) {
        return new FamilyController(
                familyService,
                mock(FamilyPermissionService.class),
                mock(HealthService.class),
                mock(ReminderService.class),
                mock(EmergencyService.class),
                mock(AgentService.class)
        );
    }

    private void authenticateAs(Long userId) {
        JwtService.JwtUser principal = new JwtService.JwtUser(userId, "family-test");
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(principal, null, List.of())
        );
    }
}

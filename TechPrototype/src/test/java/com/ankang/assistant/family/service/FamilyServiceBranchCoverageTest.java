package com.ankang.assistant.family.service;

import com.ankang.assistant.family.dto.BindPatientRequest;
import com.ankang.assistant.family.entity.CareRelation;
import com.ankang.assistant.family.mapper.CareRelationMapper;
import com.ankang.assistant.health.service.HealthService;
import com.ankang.assistant.health.vo.HealthSummaryVO;
import com.ankang.assistant.user.entity.User;
import com.ankang.assistant.user.mapper.UserMapper;
import com.baomidou.mybatisplus.core.MybatisConfiguration;
import com.baomidou.mybatisplus.core.metadata.TableInfoHelper;
import org.apache.ibatis.builder.MapperBuilderAssistant;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class FamilyServiceBranchCoverageTest {

    @Mock CareRelationMapper careRelationMapper;
    @Mock UserMapper userMapper;
    @Mock HealthService healthService;

    private FamilyService service;

    @BeforeEach
    void setUp() {
        TableInfoHelper.initTableInfo(
                new MapperBuilderAssistant(new MybatisConfiguration(), ""), CareRelation.class);
        service = new FamilyService(careRelationMapper, userMapper, healthService);
    }

    @Test
    void bindCoversMissingExpirationAndNullRelationId() {
        when(userMapper.selectById(2L)).thenReturn(user(2L, "care", "家属"));
        CareRelation invite = invite(null, 1L, null);
        when(careRelationMapper.selectOne(any())).thenReturn(invite);

        assertThatThrownBy(() -> service.bindPatient(
                2L, new BindPatientRequest("CODE12", null)))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("无效");
    }

    @Test
    void bindExistingInviteWithSameIdDoesNotNeedRemoval() {
        User caregiver = user(2L, "care", "家属");
        User patient = user(1L, "patient", "患者");
        CareRelation invite = invite(10L, 1L, LocalDateTime.now().plusMinutes(5));
        invite.setCaregiverUserId(2L);
        when(userMapper.selectById(2L)).thenReturn(caregiver);
        when(userMapper.selectById(1L)).thenReturn(patient);
        when(careRelationMapper.selectOne(any())).thenReturn(invite, invite);
        when(healthService.getSummaryByUserId(1L)).thenReturn(
                new HealthSummaryVO(90, "ok", List.of()));

        assertThat(service.bindPatient(
                2L, new BindPatientRequest("CODE12", null)).relationType())
                .isEqualTo("other");
    }

    @Test
    void privateHelpersCoverNullZeroBlankAndFallbackBranches() {
        assertThatThrownBy(() -> ReflectionTestUtils.invokeMethod(
                service, "assertValidUser", 0L, "bad"))
                .isInstanceOf(IllegalArgumentException.class);

        when(careRelationMapper.selectCount(any())).thenReturn(0L);
        assertThat((String) ReflectionTestUtils.invokeMethod(service, "uniqueInviteCode"))
                .hasSize(6);

        assertThatThrownBy(() -> ReflectionTestUtils.invokeMethod(
                service, "normalizeInviteCode", (Object) null))
                .isInstanceOf(IllegalArgumentException.class);
        assertThat((String) ReflectionTestUtils.invokeMethod(
                service, "normalizeRelationType", (Object) null)).isEqualTo("other");
        assertThat((List<?>) ReflectionTestUtils.invokeMethod(
                service, "parsePermissions", " ")).isEmpty();
    }

    @Test
    void displayNamesCoverNullUsersAndNullIdentityFields() {
        assertThat((String) ReflectionTestUtils.invokeMethod(
                service, "displayName", (Object) null)).isEqualTo("用户 null");

        User nameless = new User();
        nameless.setId(3L);
        nameless.setNickname(" ");
        nameless.setUsername(null);
        assertThat((String) ReflectionTestUtils.invokeMethod(
                service, "displayName", nameless, 3L)).isEqualTo("用户 3");
    }

    @Test
    void caregiverAndRiskHelpersCoverMissingObjectsAndMetricCollections() {
        CareRelation relation = new CareRelation();
        relation.setCaregiverUserId(9L);
        relation.setRelationType("family");
        when(userMapper.selectById(9L)).thenReturn(null);
        Object contact = ReflectionTestUtils.invokeMethod(service, "toCaregiverContactVO", relation);
        assertThat(ReflectionTestUtils.getField(contact, "phone")).isNull();

        HealthSummaryVO nullMetrics = new HealthSummaryVO(0, "unknown", null);
        HealthSummaryVO emptyMetrics = new HealthSummaryVO(0, "unknown", List.of());
        assertThat((String) ReflectionTestUtils.invokeMethod(
                service, "riskLevel", nullMetrics)).isEqualTo("unknown");
        assertThat((String) ReflectionTestUtils.invokeMethod(
                service, "riskLevel", emptyMetrics)).isEqualTo("unknown");
    }

    private CareRelation invite(Long id, Long patientId, LocalDateTime expiresAt) {
        CareRelation relation = new CareRelation();
        relation.setId(id);
        relation.setPatientUserId(patientId);
        relation.setStatus("PENDING");
        relation.setInviteCode("CODE12");
        relation.setInviteExpireAt(expiresAt);
        return relation;
    }

    private User user(Long id, String username, String nickname) {
        User user = new User();
        user.setId(id);
        user.setUsername(username);
        user.setNickname(nickname);
        return user;
    }
}

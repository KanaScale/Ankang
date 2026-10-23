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

import java.time.LocalDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.atLeastOnce;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class FamilyServiceTest {

    @Mock CareRelationMapper careRelationMapper;
    @Mock UserMapper userMapper;
    @Mock HealthService healthService;

    private FamilyService service;

    @BeforeEach
    void setUp() {
        TableInfoHelper.initTableInfo(
                new MapperBuilderAssistant(new MybatisConfiguration(), ""), CareRelation.class
        );
        service = new FamilyService(careRelationMapper, userMapper, healthService);
    }

    @Test
    void createsInviteAndRejectsInvalidUsersOrExhaustedCodes() {
        when(userMapper.selectById(1L)).thenReturn(user(1L, "patient", "患者"));
        when(careRelationMapper.selectCount(any())).thenReturn(null);
        when(careRelationMapper.insert(any(CareRelation.class))).thenAnswer(invocation -> {
            CareRelation relation = invocation.getArgument(0);
            relation.setId(10L);
            return 1;
        });

        var invite = service.createInvite(1L);
        assertThat(invite.inviteCode()).hasSize(6);
        assertThat(invite.expireAt()).isAfter(LocalDateTime.now());

        assertThatThrownBy(() -> service.createInvite(null)).hasMessage("当前用户不存在");
        when(userMapper.selectById(2L)).thenReturn(null);
        assertThatThrownBy(() -> service.createInvite(2L)).hasMessage("当前用户不存在");

        when(careRelationMapper.selectCount(any())).thenReturn(1L);
        assertThatThrownBy(() -> service.createInvite(1L)).isInstanceOf(IllegalStateException.class);
    }

    @Test
    void bindsNewRelationAndNormalizesCodeAndRelationType() {
        User caregiver = user(2L, "caregiver", "家属");
        User patient = user(1L, "patient", "患者");
        CareRelation invite = pendingInvite(10L, 1L, LocalDateTime.now().plusMinutes(10));
        when(userMapper.selectById(2L)).thenReturn(caregiver);
        when(userMapper.selectById(1L)).thenReturn(patient);
        when(careRelationMapper.selectOne(any())).thenReturn(invite, null);
        when(healthService.getSummaryByUserId(1L)).thenReturn(summary("warning"));
        when(healthService.getLastRecordTimeByUserId(1L)).thenReturn(LocalDateTime.now());

        var bound = service.bindPatient(2L, new BindPatientRequest(" abcd23 ", " daughter "));

        assertThat(bound.patientUserId()).isEqualTo(1L);
        assertThat(bound.patientName()).isEqualTo("患者");
        assertThat(bound.relationType()).isEqualTo("daughter");
        assertThat(bound.riskLevel()).isEqualTo("medium");
        assertThat(bound.permissions()).containsExactly(
                FamilyService.VIEW_HEALTH,
                FamilyService.VIEW_REMINDER,
                FamilyService.VIEW_SOS,
                FamilyService.ASK_AGENT
        );
        verify(careRelationMapper).updateById(invite);
    }

    @Test
    void reactivatesExistingRelationAndRemovesConsumedInvite() {
        CareRelation invite = pendingInvite(10L, 1L, LocalDateTime.now().plusMinutes(10));
        CareRelation existing = activeRelation(20L, 1L, 2L);
        existing.setStatus("REMOVED");
        when(userMapper.selectById(2L)).thenReturn(user(2L, "care", null));
        when(userMapper.selectById(1L)).thenReturn(user(1L, "patient", null));
        when(careRelationMapper.selectOne(any())).thenReturn(invite, existing);
        when(healthService.getSummaryByUserId(1L)).thenReturn(summary("danger"));

        var bound = service.bindPatient(2L, new BindPatientRequest("CODE12", " "));

        assertThat(bound.relationType()).isEqualTo("other");
        assertThat(bound.riskLevel()).isEqualTo("high");
        verify(careRelationMapper, atLeastOnce()).update(any(), any());
    }

    @Test
    void rejectsInvalidExpiredSelfAndMissingPatientBindings() {
        when(userMapper.selectById(2L)).thenReturn(user(2L, "care", null));
        when(careRelationMapper.selectOne(any())).thenReturn(null);
        assertThatThrownBy(() -> service.bindPatient(2L, new BindPatientRequest("CODE12", null)))
                .hasMessageContaining("无效");

        CareRelation expired = pendingInvite(11L, 1L, LocalDateTime.now().minusMinutes(1));
        when(careRelationMapper.selectOne(any())).thenReturn(expired);
        assertThatThrownBy(() -> service.bindPatient(2L, new BindPatientRequest("CODE12", null)))
                .hasMessageContaining("过期");
        verify(careRelationMapper).update(any(), any());

        CareRelation self = pendingInvite(12L, 2L, LocalDateTime.now().plusMinutes(1));
        when(careRelationMapper.selectOne(any())).thenReturn(self);
        assertThatThrownBy(() -> service.bindPatient(2L, new BindPatientRequest("CODE12", null)))
                .hasMessageContaining("自己");

        CareRelation missing = pendingInvite(13L, 3L, LocalDateTime.now().plusMinutes(1));
        when(careRelationMapper.selectOne(any())).thenReturn(missing);
        when(userMapper.selectById(3L)).thenReturn(null);
        assertThatThrownBy(() -> service.bindPatient(2L, new BindPatientRequest("CODE12", null)))
                .hasMessageContaining("被照护者");

        assertThatThrownBy(() -> service.bindPatient(2L, new BindPatientRequest(" ", null)))
                .hasMessageContaining("绑定码");
    }

    @Test
    void listsPatientsCaregiversAndFamilySummaryWithFallbackNamesAndRisks() {
        CareRelation first = activeRelation(1L, 10L, 2L);
        first.setPermissions(" VIEW_HEALTH, ,VIEW_SOS ");
        CareRelation second = activeRelation(2L, 11L, 2L);
        second.setPermissions(null);
        when(userMapper.selectById(2L)).thenReturn(user(2L, "care", null));
        when(careRelationMapper.selectList(any())).thenReturn(List.of(first, second));
        when(userMapper.selectById(10L)).thenReturn(user(10L, "patient10", ""));
        when(userMapper.selectById(11L)).thenReturn(null);
        when(healthService.getSummaryByUserId(10L)).thenReturn(summary("normal"));
        when(healthService.getSummaryByUserId(11L)).thenReturn(null);

        var patients = service.listBoundPatients(2L);
        assertThat(patients).hasSize(2);
        assertThat(patients.get(0).patientName()).isEqualTo("patient10");
        assertThat(patients.get(0).riskLevel()).isEqualTo("low");
        assertThat(patients.get(1).patientName()).isEqualTo("用户 11");
        assertThat(patients.get(1).riskLevel()).isEqualTo("unknown");
        assertThat(patients.get(1).permissions()).isEmpty();

        CareRelation caregiverRelation = activeRelation(3L, 10L, 20L);
        when(careRelationMapper.selectList(any())).thenReturn(List.of(caregiverRelation));
        User caregiver = user(20L, "", "");
        caregiver.setPhone("13800000000");
        when(userMapper.selectById(20L)).thenReturn(caregiver);
        var caregivers = service.listCaregiversForPatient(10L);
        assertThat(caregivers.get(0).name()).isEqualTo("用户 20");
        assertThat(caregivers.get(0).phone()).isEqualTo("13800000000");

        when(userMapper.selectById(10L)).thenReturn(user(10L, "patient10", "患者十"));
        when(healthService.getLastRecordTimeByUserId(10L)).thenReturn(LocalDateTime.now());
        when(healthService.getSummaryByUserId(10L)).thenReturn(summary("normal"));
        assertThat(service.buildFamilyHealthSummary(10L).patientName()).isEqualTo("患者十");
    }

    @Test
    void removesRelationsForPatientOrCaregiverAndReportsMissing() {
        when(careRelationMapper.update(eq(null), any())).thenReturn(1);
        service.removeRelation(1L, 1L);
        service.removeRelation(2L, 1L);

        assertThatThrownBy(() -> service.removeRelation(null, 1L)).hasMessageContaining("不存在");
        assertThatThrownBy(() -> service.removeRelation(1L, null)).hasMessageContaining("不存在");

        when(careRelationMapper.update(eq(null), any())).thenReturn(0);
        assertThatThrownBy(() -> service.removeRelation(2L, 1L)).hasMessageContaining("不存在");
    }

    private User user(Long id, String username, String nickname) {
        User user = new User();
        user.setId(id);
        user.setUsername(username);
        user.setNickname(nickname);
        return user;
    }

    private CareRelation pendingInvite(Long id, Long patientId, LocalDateTime expiresAt) {
        CareRelation relation = new CareRelation();
        relation.setId(id);
        relation.setPatientUserId(patientId);
        relation.setStatus("PENDING");
        relation.setInviteCode("CODE12");
        relation.setInviteExpireAt(expiresAt);
        return relation;
    }

    private CareRelation activeRelation(Long id, Long patientId, Long caregiverId) {
        CareRelation relation = new CareRelation();
        relation.setId(id);
        relation.setPatientUserId(patientId);
        relation.setCaregiverUserId(caregiverId);
        relation.setRelationType("family");
        relation.setPermissions("VIEW_HEALTH,VIEW_REMINDER");
        relation.setStatus("ACTIVE");
        relation.setUpdatedAt(LocalDateTime.now());
        return relation;
    }

    private HealthSummaryVO summary(String status) {
        return new HealthSummaryVO(
                80,
                "ok",
                List.of(new HealthSummaryVO.MetricVO("heart_rate", "心率", "80", "bpm", status, "stable"))
        );
    }
}

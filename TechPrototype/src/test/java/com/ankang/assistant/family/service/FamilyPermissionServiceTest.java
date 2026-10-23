package com.ankang.assistant.family.service;

import com.ankang.assistant.family.entity.CareRelation;
import com.ankang.assistant.family.mapper.CareRelationMapper;
import org.junit.jupiter.api.Test;
import org.springframework.security.access.AccessDeniedException;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class FamilyPermissionServiceTest {

    @Test
    void boundCaregiverCanAccessPatientData() {
        CareRelationMapper mapper = mock(CareRelationMapper.class);
        CareRelation relation = new CareRelation();
        relation.setPatientUserId(1L);
        relation.setCaregiverUserId(7L);
        relation.setStatus("ACTIVE");
        relation.setPermissions("VIEW_HEALTH,VIEW_REMINDER,VIEW_SOS,ASK_AGENT");
        when(mapper.selectOne(any())).thenReturn(relation);

        FamilyPermissionService service = new FamilyPermissionService(mapper);

        assertThatCode(() -> service.checkCaregiverAccess(7L, 1L, FamilyService.VIEW_HEALTH))
                .doesNotThrowAnyException();
    }

    @Test
    void unboundCaregiverCannotAccessPatientData() {
        CareRelationMapper mapper = mock(CareRelationMapper.class);
        when(mapper.selectOne(any())).thenReturn(null);

        FamilyPermissionService service = new FamilyPermissionService(mapper);

        assertThatThrownBy(() -> service.checkCaregiverAccess(7L, 2L, FamilyService.VIEW_HEALTH))
                .isInstanceOf(AccessDeniedException.class)
                .hasMessageContaining("未获得");
    }

    @Test
    void coversConvenienceMethodsInvalidIdsMissingPermissionAndPermissionViews() {
        CareRelationMapper mapper = mock(CareRelationMapper.class);
        FamilyPermissionService service = new FamilyPermissionService(mapper);
        assertThat(service.hasCaregiverAccess(null, 1L)).isFalse();
        assertThat(service.hasCaregiverAccess(1L, 0L)).isFalse();
        when(mapper.selectOne(any())).thenReturn(null);
        assertThat(service.permissionFor(7L, 1L).status()).isEqualTo("NONE");

        CareRelation relation = new CareRelation();
        relation.setPatientUserId(1L);
        relation.setCaregiverUserId(7L);
        relation.setStatus("ACTIVE");
        relation.setPermissions(" VIEW_HEALTH, ,ASK_AGENT ");
        when(mapper.selectOne(any())).thenReturn(relation);
        assertThat(service.hasCaregiverAccess(7L, 1L)).isTrue();
        assertThat(service.hasCaregiverAccess(7L, 1L, "VIEW_HEALTH")).isTrue();
        assertThat(service.hasCaregiverAccess(7L, 1L, "VIEW_SOS")).isFalse();
        service.checkCaregiverAccess(7L, 1L);
        assertThat(service.permissionFor(7L, 1L).permissions())
                .containsExactly("VIEW_HEALTH", "ASK_AGENT");

        relation.setPermissions(" ");
        assertThat(service.permissionFor(7L, 1L).permissions()).isEmpty();
    }
}

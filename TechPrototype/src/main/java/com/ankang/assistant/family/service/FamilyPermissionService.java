package com.ankang.assistant.family.service;

import com.ankang.assistant.family.entity.CareRelation;
import com.ankang.assistant.family.mapper.CareRelationMapper;
import com.ankang.assistant.family.vo.FamilyPermissionVO;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;

import java.util.Arrays;
import java.util.List;

@Service
public class FamilyPermissionService {

    private final CareRelationMapper careRelationMapper;

    public FamilyPermissionService(CareRelationMapper careRelationMapper) {
        this.careRelationMapper = careRelationMapper;
    }

    public void checkCaregiverAccess(Long caregiverUserId, Long patientUserId) {
        checkCaregiverAccess(caregiverUserId, patientUserId, null);
    }

    public void checkCaregiverAccess(Long caregiverUserId, Long patientUserId, String permission) {
        if (!hasCaregiverAccess(caregiverUserId, patientUserId, permission)) {
            throw new AccessDeniedException("未获得该被照护者的数据访问授权");
        }
    }

    public boolean hasCaregiverAccess(Long caregiverUserId, Long patientUserId) {
        return hasCaregiverAccess(caregiverUserId, patientUserId, null);
    }

    public boolean hasCaregiverAccess(Long caregiverUserId, Long patientUserId, String permission) {
        if (caregiverUserId == null || patientUserId == null || caregiverUserId <= 0 || patientUserId <= 0) {
            return false;
        }
        CareRelation relation = activeRelation(caregiverUserId, patientUserId);
        if (relation == null) {
            return false;
        }
        return permission == null || parsePermissions(relation.getPermissions()).contains(permission);
    }

    public FamilyPermissionVO permissionFor(Long caregiverUserId, Long patientUserId) {
        CareRelation relation = activeRelation(caregiverUserId, patientUserId);
        if (relation == null) {
            return new FamilyPermissionVO(patientUserId, caregiverUserId, List.of(), "NONE");
        }
        return new FamilyPermissionVO(
                patientUserId,
                caregiverUserId,
                parsePermissions(relation.getPermissions()),
                relation.getStatus()
        );
    }

    private CareRelation activeRelation(Long caregiverUserId, Long patientUserId) {
        return careRelationMapper.selectOne(new LambdaQueryWrapper<CareRelation>()
                .eq(CareRelation::getCaregiverUserId, caregiverUserId)
                .eq(CareRelation::getPatientUserId, patientUserId)
                .eq(CareRelation::getStatus, "ACTIVE")
                .last("limit 1"));
    }

    private List<String> parsePermissions(String permissions) {
        if (permissions == null || permissions.isBlank()) {
            return List.of();
        }
        return Arrays.stream(permissions.split(","))
                .map(String::trim)
                .filter(item -> !item.isEmpty())
                .toList();
    }
}

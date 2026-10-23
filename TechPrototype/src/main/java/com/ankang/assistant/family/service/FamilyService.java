package com.ankang.assistant.family.service;

import com.ankang.assistant.family.dto.BindPatientRequest;
import com.ankang.assistant.family.entity.CareRelation;
import com.ankang.assistant.family.mapper.CareRelationMapper;
import com.ankang.assistant.family.vo.BoundPatientVO;
import com.ankang.assistant.family.vo.FamilyCaregiverContactVO;
import com.ankang.assistant.family.vo.FamilyHealthSummaryVO;
import com.ankang.assistant.family.vo.FamilyInviteVO;
import com.ankang.assistant.health.service.HealthService;
import com.ankang.assistant.health.vo.HealthSummaryVO;
import com.ankang.assistant.user.entity.User;
import com.ankang.assistant.user.mapper.UserMapper;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;

@Service
public class FamilyService {

    public static final String VIEW_HEALTH = "VIEW_HEALTH";
    public static final String VIEW_REMINDER = "VIEW_REMINDER";
    public static final String VIEW_SOS = "VIEW_SOS";
    public static final String ASK_AGENT = "ASK_AGENT";

    private static final List<String> DEFAULT_PERMISSIONS = List.of(
            VIEW_HEALTH, VIEW_REMINDER, VIEW_SOS, ASK_AGENT
    );
    private static final String DEFAULT_PERMISSION_TEXT = String.join(",", DEFAULT_PERMISSIONS);
    private static final String INVITE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    private static final int INVITE_CODE_LENGTH = 6;
    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    private final CareRelationMapper careRelationMapper;
    private final UserMapper userMapper;
    private final HealthService healthService;

    public FamilyService(CareRelationMapper careRelationMapper, UserMapper userMapper, HealthService healthService) {
        this.careRelationMapper = careRelationMapper;
        this.userMapper = userMapper;
        this.healthService = healthService;
    }

    @Transactional
    public FamilyInviteVO createInvite(Long patientUserId) {
        assertValidUser(patientUserId, "当前用户不存在");
        LocalDateTime now = LocalDateTime.now();
        String code = uniqueInviteCode();

        CareRelation invite = new CareRelation();
        invite.setPatientUserId(patientUserId);
        invite.setCaregiverUserId(null);
        invite.setRelationType(null);
        invite.setPermissions(DEFAULT_PERMISSION_TEXT);
        invite.setStatus("PENDING");
        invite.setInviteCode(code);
        invite.setInviteExpireAt(now.plusMinutes(30));
        careRelationMapper.insert(invite);

        return new FamilyInviteVO(code, invite.getInviteExpireAt());
    }

    @Transactional
    public BoundPatientVO bindPatient(Long caregiverUserId, BindPatientRequest request) {
        assertValidUser(caregiverUserId, "当前用户不存在");
        String inviteCode = normalizeInviteCode(request.inviteCode());
        CareRelation invite = careRelationMapper.selectOne(new LambdaQueryWrapper<CareRelation>()
                .eq(CareRelation::getInviteCode, inviteCode)
                .eq(CareRelation::getStatus, "PENDING")
                .last("limit 1"));
        if (invite == null || invite.getInviteExpireAt() == null
                || invite.getInviteExpireAt().isBefore(LocalDateTime.now())) {
            if (invite != null) {
                markRemoved(invite.getId());
            }
            throw new IllegalArgumentException("绑定码无效或已过期");
        }
        Long patientUserId = invite.getPatientUserId();
        if (patientUserId.equals(caregiverUserId)) {
            throw new IllegalArgumentException("不能绑定自己的账号作为被照护者");
        }
        assertValidUser(patientUserId, "被照护者账号不存在");

        CareRelation existing = findRelation(patientUserId, caregiverUserId);
        String relationType = normalizeRelationType(request.relationType());
        if (existing == null) {
            invite.setCaregiverUserId(caregiverUserId);
            invite.setRelationType(relationType);
            invite.setPermissions(DEFAULT_PERMISSION_TEXT);
            invite.setStatus("ACTIVE");
            invite.setInviteCode(null);
            invite.setInviteExpireAt(null);
            careRelationMapper.updateById(invite);
            existing = invite;
        } else {
            existing.setRelationType(relationType);
            existing.setPermissions(DEFAULT_PERMISSION_TEXT);
            existing.setStatus("ACTIVE");
            existing.setInviteCode(null);
            existing.setInviteExpireAt(null);
            careRelationMapper.updateById(existing);
            if (!existing.getId().equals(invite.getId())) {
                markRemoved(invite.getId());
            }
        }
        return toBoundPatientVO(existing);
    }

    public List<BoundPatientVO> listBoundPatients(Long caregiverUserId) {
        assertValidUser(caregiverUserId, "当前用户不存在");
        return careRelationMapper.selectList(new LambdaQueryWrapper<CareRelation>()
                        .eq(CareRelation::getCaregiverUserId, caregiverUserId)
                        .eq(CareRelation::getStatus, "ACTIVE")
                        .orderByDesc(CareRelation::getUpdatedAt)
                        .orderByDesc(CareRelation::getId))
                .stream()
                .map(this::toBoundPatientVO)
                .toList();
    }

    @Transactional
    public void removeRelation(Long currentUserId, Long patientUserId) {
        if (currentUserId == null || patientUserId == null) {
            throw new IllegalArgumentException("绑定关系不存在");
        }
        LambdaUpdateWrapper<CareRelation> update = new LambdaUpdateWrapper<CareRelation>()
                .eq(CareRelation::getPatientUserId, patientUserId)
                .in(CareRelation::getStatus, List.of("ACTIVE", "PENDING"))
                .set(CareRelation::getStatus, "REMOVED")
                .set(CareRelation::getInviteCode, null)
                .set(CareRelation::getInviteExpireAt, null);
        if (!currentUserId.equals(patientUserId)) {
            update.eq(CareRelation::getCaregiverUserId, currentUserId);
        }
        int changed = careRelationMapper.update(null, update);
        if (changed == 0) {
            throw new IllegalArgumentException("绑定关系不存在");
        }
    }

    public FamilyHealthSummaryVO buildFamilyHealthSummary(Long patientUserId) {
        User patient = assertValidUser(patientUserId, "被照护者账号不存在");
        return new FamilyHealthSummaryVO(
                patientUserId,
                displayName(patient),
                healthService.getLastRecordTimeByUserId(patientUserId),
                healthService.getSummaryByUserId(patientUserId)
        );
    }

    public List<FamilyCaregiverContactVO> listCaregiversForPatient(Long patientUserId) {
        assertValidUser(patientUserId, "被照护者账号不存在");
        return careRelationMapper.selectList(new LambdaQueryWrapper<CareRelation>()
                        .eq(CareRelation::getPatientUserId, patientUserId)
                        .eq(CareRelation::getStatus, "ACTIVE")
                        .isNotNull(CareRelation::getCaregiverUserId)
                        .orderByDesc(CareRelation::getUpdatedAt)
                        .orderByDesc(CareRelation::getId))
                .stream()
                .map(this::toCaregiverContactVO)
                .toList();
    }

    private BoundPatientVO toBoundPatientVO(CareRelation relation) {
        Long patientUserId = relation.getPatientUserId();
        User patient = userMapper.selectById(patientUserId);
        HealthSummaryVO summary = healthService.getSummaryByUserId(patientUserId);
        return new BoundPatientVO(
                patientUserId,
                displayName(patient, patientUserId),
                relation.getRelationType(),
                relation.getStatus(),
                riskLevel(summary),
                healthService.getLastRecordTimeByUserId(patientUserId),
                parsePermissions(relation.getPermissions())
        );
    }

    private FamilyCaregiverContactVO toCaregiverContactVO(CareRelation relation) {
        User caregiver = userMapper.selectById(relation.getCaregiverUserId());
        return new FamilyCaregiverContactVO(
                relation.getCaregiverUserId(),
                displayName(caregiver, relation.getCaregiverUserId()),
                relation.getRelationType(),
                caregiver == null ? null : caregiver.getPhone()
        );
    }

    private CareRelation findRelation(Long patientUserId, Long caregiverUserId) {
        return careRelationMapper.selectOne(new LambdaQueryWrapper<CareRelation>()
                .eq(CareRelation::getPatientUserId, patientUserId)
                .eq(CareRelation::getCaregiverUserId, caregiverUserId)
                .last("limit 1"));
    }

    private User assertValidUser(Long userId, String message) {
        if (userId == null || userId <= 0) {
            throw new IllegalArgumentException(message);
        }
        User user = userMapper.selectById(userId);
        if (user == null) {
            throw new IllegalArgumentException(message);
        }
        return user;
    }

    private void markRemoved(Long relationId) {
        if (relationId == null) {
            return;
        }
        careRelationMapper.update(null, new LambdaUpdateWrapper<CareRelation>()
                .eq(CareRelation::getId, relationId)
                .set(CareRelation::getStatus, "REMOVED")
                .set(CareRelation::getInviteCode, null)
                .set(CareRelation::getInviteExpireAt, null));
    }

    private String uniqueInviteCode() {
        for (int attempt = 0; attempt < 20; attempt++) {
            String code = randomInviteCode();
            Long count = careRelationMapper.selectCount(new LambdaQueryWrapper<CareRelation>()
                    .eq(CareRelation::getInviteCode, code)
                    .in(CareRelation::getStatus, List.of("PENDING", "ACTIVE")));
            if (count == null || count == 0) {
                return code;
            }
        }
        throw new IllegalStateException("绑定码生成失败，请稍后再试");
    }

    private String randomInviteCode() {
        StringBuilder builder = new StringBuilder(INVITE_CODE_LENGTH);
        for (int index = 0; index < INVITE_CODE_LENGTH; index++) {
            builder.append(INVITE_ALPHABET.charAt(SECURE_RANDOM.nextInt(INVITE_ALPHABET.length())));
        }
        return builder.toString();
    }

    private String normalizeInviteCode(String inviteCode) {
        if (inviteCode == null || inviteCode.isBlank()) {
            throw new IllegalArgumentException("请输入绑定码");
        }
        return inviteCode.trim().toUpperCase(Locale.ROOT);
    }

    private String normalizeRelationType(String relationType) {
        if (relationType == null || relationType.isBlank()) {
            return "other";
        }
        return relationType.trim();
    }

    private String displayName(User user) {
        return displayName(user, user == null ? null : user.getId());
    }

    private String displayName(User user, Long userId) {
        if (user == null) {
            return "用户 " + userId;
        }
        if (user.getNickname() != null && !user.getNickname().isBlank()) {
            return user.getNickname();
        }
        if (user.getUsername() != null && !user.getUsername().isBlank()) {
            return user.getUsername();
        }
        return "用户 " + user.getId();
    }

    private String riskLevel(HealthSummaryVO summary) {
        if (summary == null || summary.metrics() == null || summary.metrics().isEmpty()) {
            return "unknown";
        }
        boolean danger = summary.metrics().stream().anyMatch(metric -> "danger".equals(metric.status()));
        if (danger) {
            return "high";
        }
        boolean warning = summary.metrics().stream().anyMatch(metric -> "warning".equals(metric.status()));
        return warning ? "medium" : "low";
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

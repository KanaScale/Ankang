package com.ankang.assistant.user.service;

import com.ankang.assistant.config.SecurityUtils;
import com.ankang.assistant.health.entity.HealthRecord;
import com.ankang.assistant.health.mapper.HealthRecordMapper;
import com.ankang.assistant.user.dto.HealthGoalUpdateDTO;
import com.ankang.assistant.user.dto.HealthProfileUpdateDTO;
import com.ankang.assistant.user.dto.PasswordChangeDTO;
import com.ankang.assistant.user.dto.UserProfileUpdateDTO;
import com.ankang.assistant.user.dto.UserSettingUpdateDTO;
import com.ankang.assistant.user.entity.HealthGoal;
import com.ankang.assistant.user.entity.HealthProfile;
import com.ankang.assistant.user.entity.User;
import com.ankang.assistant.user.entity.UserSetting;
import com.ankang.assistant.user.mapper.HealthGoalMapper;
import com.ankang.assistant.user.mapper.HealthProfileMapper;
import com.ankang.assistant.user.mapper.UserMapper;
import com.ankang.assistant.user.mapper.UserSettingMapper;
import com.ankang.assistant.user.vo.HealthGoalVO;
import com.ankang.assistant.user.vo.HealthGoalProgressItemVO;
import com.ankang.assistant.user.vo.HealthGoalProgressVO;
import com.ankang.assistant.user.vo.HealthProfileVO;
import com.ankang.assistant.user.vo.UserProfileVO;
import com.ankang.assistant.user.vo.UserSettingVO;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HexFormat;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Service
public class UserService {

    private static final String PASSWORD_HASH_PREFIX = "sha256:";
    private static final BigDecimal DEFAULT_FONT_SCALE = new BigDecimal("1.00");

    private final UserMapper userMapper;
    private final HealthProfileMapper healthProfileMapper;
    private final HealthGoalMapper healthGoalMapper;
    private final HealthRecordMapper healthRecordMapper;
    private final UserSettingMapper userSettingMapper;
    private final PasswordEncoder passwordEncoder;
    private final ObjectMapper objectMapper;

    public UserService(
            UserMapper userMapper,
            HealthProfileMapper healthProfileMapper,
            HealthGoalMapper healthGoalMapper,
            HealthRecordMapper healthRecordMapper,
            UserSettingMapper userSettingMapper,
            PasswordEncoder passwordEncoder,
            ObjectMapper objectMapper
    ) {
        this.userMapper = userMapper;
        this.healthProfileMapper = healthProfileMapper;
        this.healthGoalMapper = healthGoalMapper;
        this.healthRecordMapper = healthRecordMapper;
        this.userSettingMapper = userSettingMapper;
        this.passwordEncoder = passwordEncoder;
        this.objectMapper = objectMapper;
    }

    public UserProfileVO getProfile() {
        return getProfileByUserId(SecurityUtils.currentUserId());
    }

    public UserProfileVO getProfileByUserId(Long userId) {
        User user = userMapper.selectById(userId);
        if (user == null) {
            throw new IllegalArgumentException("用户不存在");
        }
        return toUserProfileVO(user);
    }

    @Transactional
    public UserProfileVO updateProfile(UserProfileUpdateDTO dto) {
        User user = currentUserEntity();
        user.setNickname(blankToNull(dto.nickname()));
        user.setAge(dto.age());
        user.setGender(blankToNull(dto.gender()));
        user.setPhone(blankToNull(dto.phone()));
        user.setEmail(blankToNull(dto.email()));
        user.setAvatarUrl(blankToNull(dto.avatarUrl()));
        userMapper.update(new LambdaUpdateWrapper<User>()
                .eq(User::getId, user.getId())
                .set(User::getUsername, user.getUsername())
                .set(User::getNickname, user.getNickname())
                .set(User::getAge, user.getAge())
                .set(User::getGender, user.getGender())
                .set(User::getPhone, user.getPhone())
                .set(User::getEmail, user.getEmail())
                .set(User::getAvatarUrl, user.getAvatarUrl()));
        return toUserProfileVO(currentUserEntity());
    }

    @Transactional
    public void changePassword(PasswordChangeDTO dto) {
        if (!hasText(dto.oldPassword())) {
            throw new IllegalArgumentException("请输入原密码");
        }
        if (!hasText(dto.newPassword()) || dto.newPassword().length() < 6) {
            throw new IllegalArgumentException("新密码至少 6 位");
        }
        if (!dto.newPassword().equals(dto.confirmPassword())) {
            throw new IllegalArgumentException("两次输入的新密码不一致");
        }

        User user = currentUserEntity();
        if (!matchesPassword(dto.oldPassword(), user.getPasswordHash())) {
            throw new IllegalArgumentException("原密码错误");
        }

        user.setPasswordHash(passwordEncoder.encode(dto.newPassword()));
        userMapper.updateById(user);
    }

    public HealthProfileVO getHealthProfile() {
        return getHealthProfileByUserId(SecurityUtils.currentUserId());
    }

    public HealthProfileVO getHealthProfileByUserId(Long userId) {
        HealthProfile profile = findHealthProfile(userId);
        if (profile == null) {
            return buildHealthProfile(null, null, List.of(), null, null, null);
        }
        return toHealthProfileVO(profile);
    }

    @Transactional
    public HealthProfileVO updateHealthProfile(HealthProfileUpdateDTO dto) {
        Long userId = SecurityUtils.currentUserId();
        HealthProfile profile = findHealthProfile(userId);
        if (profile == null) {
            profile = new HealthProfile();
            profile.setUserId(userId);
        }

        profile.setHeight(dto.height());
        profile.setWeight(dto.weight());
        profile.setChronicDiseases(toJson(dto.chronicDiseases()));
        profile.setAllergies(blankToNull(dto.allergies()));
        profile.setMedicalHistory(blankToNull(dto.medicalHistory()));
        profile.setDevice(blankToNull(dto.device()));

        if (profile.getId() == null) {
            healthProfileMapper.insert(profile);
        } else {
            healthProfileMapper.update(new LambdaUpdateWrapper<HealthProfile>()
                    .eq(HealthProfile::getId, profile.getId())
                    .set(HealthProfile::getHeight, profile.getHeight())
                    .set(HealthProfile::getWeight, profile.getWeight())
                    .set(HealthProfile::getChronicDiseases, profile.getChronicDiseases())
                    .set(HealthProfile::getAllergies, profile.getAllergies())
                    .set(HealthProfile::getMedicalHistory, profile.getMedicalHistory())
                    .set(HealthProfile::getDevice, profile.getDevice()));
        }
        return toHealthProfileVO(findHealthProfile(userId));
    }

    public HealthGoalVO getHealthGoal() {
        return getHealthGoalByUserId(SecurityUtils.currentUserId());
    }

    public HealthGoalVO getHealthGoalByUserId(Long userId) {
        HealthGoal goal = findHealthGoal(userId);
        if (goal == null) {
            return new HealthGoalVO("8000", null, "7.5", null, "140/90", null);
        }
        return toHealthGoalVO(goal);
    }

    @Transactional
    public HealthGoalVO updateHealthGoal(HealthGoalUpdateDTO dto) {
        Long userId = SecurityUtils.currentUserId();
        HealthGoal goal = findHealthGoal(userId);
        if (goal == null) {
            goal = new HealthGoal();
            goal.setUserId(userId);
        }
        String stepsTarget = validateStepsTarget(dto.stepsTarget());
        String sleepTarget = validateSleepTarget(dto.sleepTarget());
        String bloodPressureTarget = validateBloodPressureTarget(dto.bloodPressureTarget());

        goal.setStepsTarget(stepsTarget);
        goal.setStepsNote(blankToNull(dto.stepsNote()));
        goal.setSleepTarget(sleepTarget);
        goal.setSleepNote(blankToNull(dto.sleepNote()));
        goal.setBloodPressureTarget(bloodPressureTarget);
        goal.setBloodPressureNote(blankToNull(dto.bloodPressureNote()));

        if (goal.getId() == null) {
            healthGoalMapper.insert(goal);
        } else {
            healthGoalMapper.update(new LambdaUpdateWrapper<HealthGoal>()
                    .eq(HealthGoal::getId, goal.getId())
                    .set(HealthGoal::getStepsTarget, goal.getStepsTarget())
                    .set(HealthGoal::getStepsNote, goal.getStepsNote())
                    .set(HealthGoal::getSleepTarget, goal.getSleepTarget())
                    .set(HealthGoal::getSleepNote, goal.getSleepNote())
                    .set(HealthGoal::getBloodPressureTarget, goal.getBloodPressureTarget())
                    .set(HealthGoal::getBloodPressureNote, goal.getBloodPressureNote()));
        }
        return toHealthGoalVO(findHealthGoal(userId));
    }

    public HealthGoalProgressVO getHealthGoalProgress() {
        Long userId = SecurityUtils.currentUserId();
        HealthGoalVO goal = getHealthGoal();
        LocalDate today = LocalDate.now();
        LocalDateTime start = today.atStartOfDay();
        LocalDateTime end = today.plusDays(1).atStartOfDay();

        BigDecimal stepsTarget = parseDecimal(goal.stepsTarget(), new BigDecimal("8000"));
        BigDecimal stepsCurrent = latestMetricValue(userId, "steps", start, end);

        BigDecimal sleepTarget = parseDecimal(goal.sleepTarget(), new BigDecimal("7.5"));
        BigDecimal sleepCurrent = latestMetricValue(userId, "sleep_hours", start, end);

        int[] pressureTarget = parseBloodPressureTarget(goal.bloodPressureTarget());
        HealthRecord latestPressure = latestMetric(userId, "blood_pressure", null, null);

        return new HealthGoalProgressVO(
                quantityProgress("steps", "每日步数", stepsCurrent, stepsTarget, "步"),
                quantityProgress("sleep", "睡眠时长", sleepCurrent, sleepTarget, "小时"),
                pressureProgress(latestPressure, pressureTarget[0], pressureTarget[1])
        );
    }

    public UserSettingVO getSettings() {
        return getSettingsByUserId(SecurityUtils.currentUserId());
    }

    public UserSettingVO getSettingsByUserId(Long userId) {
        UserSetting setting = findUserSetting(userId);
        if (setting == null) {
            return defaultUserSettingVO();
        }
        return toUserSettingVO(setting);
    }

    @Transactional
    public UserSettingVO updateSettings(UserSettingUpdateDTO dto) {
        Long userId = SecurityUtils.currentUserId();
        UserSetting setting = findUserSetting(userId);
        if (setting == null) {
            setting = new UserSetting();
            setting.setUserId(userId);
        }

        setting.setFontScale(clampFontScale(dto.fontScale()));
        setting.setNotificationEnabled(dto.notificationEnabled() == null || dto.notificationEnabled());
        setting.setLargeTouchTarget(Boolean.TRUE.equals(dto.largeTouchTarget()));
        setting.setSimpleMode(Boolean.TRUE.equals(dto.simpleMode()));

        if (setting.getId() == null) {
            userSettingMapper.insert(setting);
        } else {
            userSettingMapper.update(new LambdaUpdateWrapper<UserSetting>()
                    .eq(UserSetting::getId, setting.getId())
                    .set(UserSetting::getFontScale, setting.getFontScale())
                    .set(UserSetting::getNotificationEnabled, setting.getNotificationEnabled())
                    .set(UserSetting::getLargeTouchTarget, setting.getLargeTouchTarget())
                    .set(UserSetting::getSimpleMode, setting.getSimpleMode()));
        }
        return toUserSettingVO(findUserSetting(userId));
    }

    private HealthGoalProgressItemVO quantityProgress(String key, String label, BigDecimal current,
                                                       BigDecimal target, String unit) {
        BigDecimal safeCurrent = current == null ? BigDecimal.ZERO : current;
        BigDecimal safeTarget = target == null || target.compareTo(BigDecimal.ZERO) <= 0
                ? BigDecimal.ONE : target;
        BigDecimal progress = safeCurrent.divide(safeTarget, 4, RoundingMode.HALF_UP)
                .min(BigDecimal.ONE)
                .max(BigDecimal.ZERO);
        String status = progress.compareTo(BigDecimal.ONE) >= 0
                ? "已达标"
                : progress.compareTo(new BigDecimal("0.8")) >= 0 ? "接近达标" : "进行中";
        return new HealthGoalProgressItemVO(
                key,
                label,
                formatDecimal(safeTarget) + " " + unit,
                formatDecimal(safeCurrent) + " " + unit,
                unit,
                progress,
                status
        );
    }

    private HealthGoalProgressItemVO pressureProgress(HealthRecord latestPressure,
                                                       int targetSystolic,
                                                       int targetDiastolic) {
        String targetText = "< " + targetSystolic + "/" + targetDiastolic + " mmHg";
        if (latestPressure == null || latestPressure.getSystolic() == null || latestPressure.getDiastolic() == null) {
            return new HealthGoalProgressItemVO(
                    "bloodPressure",
                    "血压管理",
                    targetText,
                    "暂无记录",
                    "mmHg",
                    BigDecimal.ZERO,
                    "待记录"
            );
        }
        boolean achieved = latestPressure.getSystolic() < targetSystolic
                && latestPressure.getDiastolic() < targetDiastolic;
        return new HealthGoalProgressItemVO(
                "bloodPressure",
                "血压管理",
                targetText,
                latestPressure.getSystolic() + "/" + latestPressure.getDiastolic() + " mmHg",
                "mmHg",
                achieved ? BigDecimal.ONE : BigDecimal.ZERO,
                achieved ? "已达标" : "需关注"
        );
    }

    private BigDecimal latestMetricValue(Long userId, String type, LocalDateTime start, LocalDateTime end) {
        HealthRecord latest = latestMetric(userId, type, start, end);
        return latest == null ? BigDecimal.ZERO : metricValue(latest);
    }

    private HealthRecord latestMetric(Long userId, String type, LocalDateTime start, LocalDateTime end) {
        return healthRecordMapper.selectOne(metricQuery(userId, type, start, end)
                .orderByDesc(HealthRecord::getRecordedAt)
                .orderByDesc(HealthRecord::getId)
                .last("limit 1"));
    }

    private LambdaQueryWrapper<HealthRecord> metricQuery(Long userId, String type,
                                                         LocalDateTime start, LocalDateTime end) {
        return new LambdaQueryWrapper<HealthRecord>()
                .eq(HealthRecord::getUserId, userId)
                .eq(HealthRecord::getType, type)
                .ge(start != null, HealthRecord::getRecordedAt, start)
                .lt(end != null, HealthRecord::getRecordedAt, end);
    }

    private BigDecimal metricValue(HealthRecord record) {
        if ("blood_pressure".equals(record.getType()) && record.getSystolic() != null) {
            return BigDecimal.valueOf(record.getSystolic());
        }
        if (record.getValue() != null) {
            return record.getValue();
        }
        return record.getValue1() == null ? BigDecimal.ZERO : record.getValue1();
    }

    private BigDecimal parseDecimal(String text, BigDecimal fallback) {
        if (text == null || text.isBlank()) {
            return fallback;
        }
        Matcher matcher = Pattern.compile("\\d+(?:[,.]\\d+)?").matcher(text.replace(",", ""));
        if (!matcher.find()) {
            return fallback;
        }
        try {
            return new BigDecimal(matcher.group().replace(",", ""));
        } catch (NumberFormatException ex) {
            return fallback;
        }
    }

    private int[] parseBloodPressureTarget(String text) {
        if (text == null || text.isBlank()) {
            return new int[]{140, 90};
        }
        Matcher matcher = Pattern.compile("(\\d{2,3})\\D+(\\d{2,3})").matcher(text);
        if (!matcher.find()) {
            return new int[]{140, 90};
        }
        try {
            return new int[]{Integer.parseInt(matcher.group(1)), Integer.parseInt(matcher.group(2))};
        } catch (NumberFormatException ex) {
            return new int[]{140, 90};
        }
    }

    private String formatDecimal(BigDecimal value) {
        return value.setScale(1, RoundingMode.HALF_UP).stripTrailingZeros().toPlainString();
    }

    private String validateStepsTarget(String text) {
        String trimmed = requireGoalText(text, "请填写步数目标");
        if (!trimmed.matches("\\d+")) {
            throw new IllegalArgumentException("步数目标只能输入 1 到 100000 的整数");
        }
        if (trimmed.length() > 6) {
            throw new IllegalArgumentException("步数目标只能输入 1 到 100000 的整数");
        }
        int value = Integer.parseInt(trimmed);
        if (value < 1 || value > 100000) {
            throw new IllegalArgumentException("步数目标只能输入 1 到 100000 的整数");
        }
        return trimmed;
    }

    private String validateSleepTarget(String text) {
        String trimmed = requireGoalText(text, "请填写睡眠目标");
        if (!trimmed.matches("\\d+(?:\\.\\d+)?")) {
            throw new IllegalArgumentException("睡眠目标只能输入 0.5 到 24 之间的数字");
        }
        BigDecimal value = new BigDecimal(trimmed);
        if (value.compareTo(new BigDecimal("0.5")) < 0 || value.compareTo(new BigDecimal("24")) > 0) {
            throw new IllegalArgumentException("睡眠目标只能输入 0.5 到 24 之间的数字");
        }
        return value.stripTrailingZeros().toPlainString();
    }

    private String validateBloodPressureTarget(String text) {
        String trimmed = requireGoalText(text, "请填写血压目标").replace('／', '/');
        Matcher matcher = Pattern.compile("^(\\d{2,3})/(\\d{2,3})$").matcher(trimmed);
        if (!matcher.matches()) {
            throw new IllegalArgumentException("血压目标格式应为 收缩压/舒张压，例如 140/90");
        }
        int systolic = Integer.parseInt(matcher.group(1));
        int diastolic = Integer.parseInt(matcher.group(2));
        if (systolic < 60 || systolic > 250 || diastolic < 40 || diastolic > 160 || systolic <= diastolic) {
            throw new IllegalArgumentException("血压目标范围不合理：收缩压 60-250，舒张压 40-160，且收缩压需大于舒张压");
        }
        return systolic + "/" + diastolic;
    }

    private String requireGoalText(String text, String message) {
        if (text == null || text.isBlank()) {
            throw new IllegalArgumentException(message);
        }
        return text.trim();
    }

    private User currentUserEntity() {
        Long userId = SecurityUtils.currentUserId();
        User user = userMapper.selectById(userId);
        if (user == null) {
            throw new IllegalArgumentException("用户不存在");
        }
        return user;
    }

    private HealthProfile findHealthProfile(Long userId) {
        return healthProfileMapper.selectOne(new LambdaQueryWrapper<HealthProfile>()
                .eq(HealthProfile::getUserId, userId)
                .last("limit 1"));
    }

    private HealthGoal findHealthGoal(Long userId) {
        return healthGoalMapper.selectOne(new LambdaQueryWrapper<HealthGoal>()
                .eq(HealthGoal::getUserId, userId)
                .last("limit 1"));
    }

    private UserSetting findUserSetting(Long userId) {
        return userSettingMapper.selectOne(new LambdaQueryWrapper<UserSetting>()
                .eq(UserSetting::getUserId, userId)
                .last("limit 1"));
    }

    private void ensureUsernameAvailable(String username, Long currentUserId) {
        User existing = userMapper.selectOne(new LambdaQueryWrapper<User>()
                .eq(User::getUsername, username.trim())
                .ne(User::getId, currentUserId)
                .last("limit 1"));
        if (existing != null) {
            throw new IllegalArgumentException("账号已被使用");
        }
    }

    private UserProfileVO toUserProfileVO(User user) {
        return new UserProfileVO(
                user.getId(),
                user.getUsername(),
                user.getNickname(),
                user.getAge(),
                user.getGender(),
                user.getPhone(),
                user.getEmail(),
                user.getAvatarUrl(),
                user.getRole() == null || user.getRole().isBlank() ? "PATIENT" : user.getRole()
        );
    }

    private HealthProfileVO toHealthProfileVO(HealthProfile profile) {
        return buildHealthProfile(
                profile.getHeight(),
                profile.getWeight(),
                fromJson(profile.getChronicDiseases()),
                profile.getAllergies(),
                profile.getMedicalHistory(),
                profile.getDevice()
        );
    }

    private HealthGoalVO toHealthGoalVO(HealthGoal goal) {
        return new HealthGoalVO(
                goal.getStepsTarget(),
                goal.getStepsNote(),
                goal.getSleepTarget(),
                goal.getSleepNote(),
                goal.getBloodPressureTarget(),
                goal.getBloodPressureNote()
        );
    }

    private UserSettingVO toUserSettingVO(UserSetting setting) {
        return new UserSettingVO(
                setting.getFontScale(),
                setting.getNotificationEnabled(),
                setting.getLargeTouchTarget(),
                setting.getSimpleMode()
        );
    }

    private UserSettingVO defaultUserSettingVO() {
        return new UserSettingVO(DEFAULT_FONT_SCALE, true, false, false);
    }

    private BigDecimal clampFontScale(BigDecimal value) {
        BigDecimal scale = value == null ? DEFAULT_FONT_SCALE : value;
        if (scale.compareTo(new BigDecimal("0.85")) < 0) {
            return new BigDecimal("0.85");
        }
        if (scale.compareTo(new BigDecimal("1.30")) > 0) {
            return new BigDecimal("1.30");
        }
        return scale.setScale(2, RoundingMode.HALF_UP);
    }

    private HealthProfileVO buildHealthProfile(
            BigDecimal height,
            BigDecimal weight,
            List<String> diseases,
            String allergies,
            String medicalHistory,
            String device
    ) {
        BigDecimal bmi = BigDecimal.ZERO;
        if (height != null && weight != null && height.compareTo(BigDecimal.ZERO) > 0) {
            BigDecimal heightInMeters = height.divide(new BigDecimal("100"), 4, RoundingMode.HALF_UP);
            bmi = weight.divide(heightInMeters.multiply(heightInMeters), 1, RoundingMode.HALF_UP);
        }
        return new HealthProfileVO(height, weight, bmi, diseases, allergies, medicalHistory, device);
    }

    private String toJson(List<String> values) {
        try {
            return objectMapper.writeValueAsString(values == null ? List.of() : values);
        } catch (JsonProcessingException ex) {
            throw new IllegalArgumentException("慢病类型格式错误", ex);
        }
    }

    private List<String> fromJson(String value) {
        if (!hasText(value)) {
            return List.of();
        }
        try {
            return objectMapper.readValue(value, new TypeReference<>() {
            });
        } catch (Exception ex) {
            return new ArrayList<>();
        }
    }

    private String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }

    private boolean hasText(String value) {
        return value != null && !value.isBlank();
    }

    private boolean matchesPassword(String rawPassword, String storedPassword) {
        if (!hasText(storedPassword)) {
            return false;
        }
        if (storedPassword.startsWith(PASSWORD_HASH_PREFIX)) {
            return hashPassword(rawPassword).equals(storedPassword);
        }
        return passwordEncoder.matches(rawPassword, storedPassword);
    }

    private String hashPassword(String password) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hashed = digest.digest(password.getBytes(StandardCharsets.UTF_8));
            return PASSWORD_HASH_PREFIX + HexFormat.of().formatHex(hashed);
        } catch (NoSuchAlgorithmException ex) {
            throw new IllegalStateException("密码摘要算法不可用", ex);
        }
    }
}

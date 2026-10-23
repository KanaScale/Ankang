package com.ankang.assistant.user.service;

import com.ankang.assistant.config.JwtService;
import com.ankang.assistant.health.entity.HealthRecord;
import com.ankang.assistant.health.mapper.HealthRecordMapper;
import com.ankang.assistant.user.dto.PasswordChangeDTO;
import com.ankang.assistant.user.dto.UserSettingUpdateDTO;
import com.ankang.assistant.user.entity.HealthGoal;
import com.ankang.assistant.user.entity.HealthProfile;
import com.ankang.assistant.user.entity.User;
import com.ankang.assistant.user.entity.UserSetting;
import com.ankang.assistant.user.mapper.HealthGoalMapper;
import com.ankang.assistant.user.mapper.HealthProfileMapper;
import com.ankang.assistant.user.mapper.UserMapper;
import com.ankang.assistant.user.mapper.UserSettingMapper;
import com.baomidou.mybatisplus.core.MybatisConfiguration;
import com.baomidou.mybatisplus.core.metadata.TableInfoHelper;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.ibatis.builder.MapperBuilderAssistant;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigDecimal;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class UserServiceBranchCoverageTest {

    @Mock UserMapper userMapper;
    @Mock HealthProfileMapper healthProfileMapper;
    @Mock HealthGoalMapper healthGoalMapper;
    @Mock HealthRecordMapper healthRecordMapper;
    @Mock UserSettingMapper userSettingMapper;
    @Mock PasswordEncoder passwordEncoder;

    private UserService service;

    @BeforeEach
    void setUp() {
        MapperBuilderAssistant assistant = new MapperBuilderAssistant(new MybatisConfiguration(), "");
        TableInfoHelper.initTableInfo(assistant, User.class);
        TableInfoHelper.initTableInfo(assistant, HealthProfile.class);
        TableInfoHelper.initTableInfo(assistant, HealthGoal.class);
        TableInfoHelper.initTableInfo(assistant, UserSetting.class);
        TableInfoHelper.initTableInfo(assistant, HealthRecord.class);
        service = new UserService(userMapper, healthProfileMapper, healthGoalMapper,
                healthRecordMapper, userSettingMapper, passwordEncoder, new ObjectMapper());
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(
                        new JwtService.JwtUser(42L, "branch-user"), null, List.of()));
    }

    @AfterEach
    void clearContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void coversEntityLookupAndViewAlternativeBranches() {
        HealthProfile profile = new HealthProfile();
        profile.setHeight(BigDecimal.ZERO);
        profile.setWeight(BigDecimal.TEN);
        profile.setChronicDiseases("");
        when(healthProfileMapper.selectOne(any())).thenReturn(profile);
        assertThat(service.getHealthProfileByUserId(7L).bmi()).isZero();

        UserSetting setting = new UserSetting();
        setting.setFontScale(BigDecimal.ONE);
        setting.setNotificationEnabled(true);
        setting.setLargeTouchTarget(true);
        setting.setSimpleMode(true);
        when(userSettingMapper.selectOne(any())).thenReturn(setting);
        assertThat(service.getSettingsByUserId(7L).simpleMode()).isTrue();

        User blankRole = user(7L, " ");
        User admin = user(8L, "ADMIN");
        when(userMapper.selectById(7L)).thenReturn(blankRole);
        when(userMapper.selectById(8L)).thenReturn(admin);
        assertThat(service.getProfileByUserId(7L).role()).isEqualTo("PATIENT");
        assertThat(service.getProfileByUserId(8L).role()).isEqualTo("ADMIN");
    }

    @Test
    void coversPasswordAndCurrentUserFailureAlternatives() {
        assertThatThrownBy(() -> service.changePassword(
                new PasswordChangeDTO("old", null, null)))
                .isInstanceOf(IllegalArgumentException.class);

        when(userMapper.selectById(42L)).thenReturn(null);
        assertThatThrownBy(() -> service.changePassword(
                new PasswordChangeDTO("old", "123456", "123456")))
                .hasMessage("用户不存在");
    }

    @Test
    void coversSettingsBooleanTrueAndDefaultScale() {
        UserSetting saved = new UserSetting();
        saved.setId(1L);
        saved.setUserId(42L);
        saved.setFontScale(BigDecimal.ONE);
        saved.setNotificationEnabled(true);
        saved.setLargeTouchTarget(false);
        saved.setSimpleMode(false);
        when(userSettingMapper.selectOne(any())).thenReturn(null, saved);

        assertThat(service.updateSettings(new UserSettingUpdateDTO(null, true, false, false))
                .notificationEnabled()).isTrue();
        assertThat((BigDecimal) ReflectionTestUtils.invokeMethod(service, "clampFontScale", (Object) null))
                .isEqualByComparingTo("1.00");
    }

    @Test
    void coversProgressBoundaryAndMissingPressureFields() {
        Object zero = ReflectionTestUtils.invokeMethod(service, "quantityProgress",
                "steps", "steps", null, null, "步");
        assertThat(ReflectionTestUtils.getField(zero, "status")).isEqualTo("进行中");

        Object negative = ReflectionTestUtils.invokeMethod(service, "quantityProgress",
                "steps", "steps", new BigDecimal("-5"), BigDecimal.ZERO, "步");
        assertThat(ReflectionTestUtils.getField(negative, "progress")).isEqualTo(BigDecimal.ZERO);

        HealthRecord missingSystolic = pressure(null, 80);
        HealthRecord missingDiastolic = pressure(120, null);
        HealthRecord highSystolic = pressure(140, 80);
        HealthRecord highDiastolic = pressure(120, 90);
        assertThat(statusOfPressure(missingSystolic)).isEqualTo("待记录");
        assertThat(statusOfPressure(missingDiastolic)).isEqualTo("待记录");
        assertThat(statusOfPressure(highSystolic)).isEqualTo("需关注");
        assertThat(statusOfPressure(highDiastolic)).isEqualTo("需关注");
    }

    @Test
    void coversMetricAndParsingShortCircuitAlternatives() {
        HealthRecord bloodPressureWithoutSystolic = new HealthRecord();
        bloodPressureWithoutSystolic.setType("blood_pressure");
        bloodPressureWithoutSystolic.setValue(BigDecimal.TEN);
        assertThat((BigDecimal) ReflectionTestUtils.invokeMethod(
                service, "metricValue", bloodPressureWithoutSystolic)).isEqualByComparingTo("10");

        assertThat((BigDecimal) ReflectionTestUtils.invokeMethod(
                service, "parseDecimal", "", BigDecimal.TEN)).isEqualByComparingTo("10");
        assertThat((int[]) ReflectionTestUtils.invokeMethod(
                service, "parseBloodPressureTarget", "")).containsExactly(140, 90);
        assertThat((List<?>) ReflectionTestUtils.invokeMethod(service, "fromJson", (Object) null)).isEmpty();
        assertThat((List<?>) ReflectionTestUtils.invokeMethod(service, "fromJson", " ")).isEmpty();
        assertThat((Boolean) ReflectionTestUtils.invokeMethod(service, "hasText", " ")).isFalse();
    }

    @Test
    void coversEveryGoalValidationComparisonOperand() {
        assertPrivateValidationFails("validateStepsTarget", "100001");
        assertPrivateValidationFails("validateSleepTarget", "0.4");
        assertPrivateValidationFails("validateBloodPressureTarget", "59/50");
        assertPrivateValidationFails("validateBloodPressureTarget", "251/90");
        assertPrivateValidationFails("validateBloodPressureTarget", "100/39");
        assertPrivateValidationFails("validateBloodPressureTarget", "200/161");
        assertPrivateValidationFails("validateBloodPressureTarget", "100/100");
        assertPrivateValidationFails("requireGoalText", " ", "required");
    }

    @Test
    void coversUsernameAvailabilityAndBmiConditionOperands() {
        when(userMapper.selectOne(any())).thenReturn(null);
        ReflectionTestUtils.invokeMethod(service, "ensureUsernameAvailable", " free ", 42L);

        when(userMapper.selectOne(any())).thenReturn(new User());
        assertThatThrownBy(() -> ReflectionTestUtils.invokeMethod(
                service, "ensureUsernameAvailable", "used", 42L))
                .isInstanceOf(IllegalArgumentException.class);

        Object heightOnly = ReflectionTestUtils.invokeMethod(service, "buildHealthProfile",
                BigDecimal.TEN, null, List.of(), null, null, null);
        Object zeroHeight = ReflectionTestUtils.invokeMethod(service, "buildHealthProfile",
                BigDecimal.ZERO, BigDecimal.TEN, List.of(), null, null, null);
        assertThat(ReflectionTestUtils.getField(heightOnly, "bmi")).isEqualTo(BigDecimal.ZERO);
        assertThat(ReflectionTestUtils.getField(zeroHeight, "bmi")).isEqualTo(BigDecimal.ZERO);
    }

    private String statusOfPressure(HealthRecord record) {
        Object result = ReflectionTestUtils.invokeMethod(service, "pressureProgress", record, 130, 85);
        return (String) ReflectionTestUtils.getField(result, "status");
    }

    private void assertPrivateValidationFails(String method, Object... args) {
        assertThatThrownBy(() -> ReflectionTestUtils.invokeMethod(service, method, args))
                .isInstanceOf(IllegalArgumentException.class);
    }

    private User user(Long id, String role) {
        User user = new User();
        user.setId(id);
        user.setUsername("user-" + id);
        user.setRole(role);
        return user;
    }

    private HealthRecord pressure(Integer systolic, Integer diastolic) {
        HealthRecord record = new HealthRecord();
        record.setType("blood_pressure");
        record.setSystolic(systolic);
        record.setDiastolic(diastolic);
        return record;
    }
}

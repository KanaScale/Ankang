package com.ankang.assistant.user.service;

import com.ankang.assistant.config.JwtService;
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
import com.ankang.assistant.user.vo.HealthGoalProgressVO;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.baomidou.mybatisplus.core.MybatisConfiguration;
import com.baomidou.mybatisplus.core.metadata.TableInfoHelper;
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
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.HexFormat;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class UserServiceFullCoverageTest {

    @Mock UserMapper userMapper;
    @Mock HealthProfileMapper healthProfileMapper;
    @Mock HealthGoalMapper healthGoalMapper;
    @Mock HealthRecordMapper healthRecordMapper;
    @Mock UserSettingMapper userSettingMapper;
    @Mock PasswordEncoder passwordEncoder;

    private UserService service;

    @BeforeEach
    void setUp() {
        MybatisConfiguration configuration = new MybatisConfiguration();
        MapperBuilderAssistant assistant = new MapperBuilderAssistant(configuration, "");
        TableInfoHelper.initTableInfo(assistant, User.class);
        TableInfoHelper.initTableInfo(assistant, HealthProfile.class);
        TableInfoHelper.initTableInfo(assistant, HealthGoal.class);
        TableInfoHelper.initTableInfo(assistant, UserSetting.class);
        TableInfoHelper.initTableInfo(assistant, HealthRecord.class);
        service = new UserService(
                userMapper,
                healthProfileMapper,
                healthGoalMapper,
                healthRecordMapper,
                userSettingMapper,
                passwordEncoder,
                new ObjectMapper()
        );
        JwtService.JwtUser principal = new JwtService.JwtUser(42L, "tester");
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(principal, null, List.of())
        );
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void coversProfileUpdatesAndPasswordFormats() throws Exception {
        User user = user(42L, "tester");
        when(userMapper.selectById(42L)).thenReturn(user);

        assertThat(service.getProfile().username()).isEqualTo("tester");
        assertThat(service.getProfileByUserId(42L).role()).isEqualTo("PATIENT");

        var updated = service.updateProfile(new UserProfileUpdateDTO(
                "ignored", "  测试员  ", 30, "男", " 138 ", " a@b.test ", " avatar "
        ));
        assertThat(updated.nickname()).isEqualTo("测试员");
        verify(userMapper).update(any());

        assertThatThrownBy(() -> service.changePassword(new PasswordChangeDTO(null, "123456", "123456")))
                .hasMessageContaining("原密码");
        assertThatThrownBy(() -> service.changePassword(new PasswordChangeDTO("old", "123", "123")))
                .hasMessageContaining("至少 6 位");
        assertThatThrownBy(() -> service.changePassword(new PasswordChangeDTO("old", "123456", "654321")))
                .hasMessageContaining("不一致");

        user.setPasswordHash(null);
        assertThatThrownBy(() -> service.changePassword(new PasswordChangeDTO("old", "123456", "123456")))
                .hasMessageContaining("原密码错误");

        user.setPasswordHash("bcrypt");
        when(passwordEncoder.matches("old", "bcrypt")).thenReturn(false, true);
        assertThatThrownBy(() -> service.changePassword(new PasswordChangeDTO("old", "123456", "123456")))
                .hasMessageContaining("原密码错误");
        when(passwordEncoder.encode("123456")).thenReturn("new-hash");
        service.changePassword(new PasswordChangeDTO("old", "123456", "123456"));
        assertThat(user.getPasswordHash()).isEqualTo("new-hash");

        String legacyHash = "sha256:" + HexFormat.of().formatHex(
                MessageDigest.getInstance("SHA-256").digest("legacy".getBytes(StandardCharsets.UTF_8))
        );
        user.setPasswordHash(legacyHash);
        when(passwordEncoder.encode("abcdef")).thenReturn("upgraded");
        service.changePassword(new PasswordChangeDTO("legacy", "abcdef", "abcdef"));
        assertThat(user.getPasswordHash()).isEqualTo("upgraded");

        when(userMapper.selectById(404L)).thenReturn(null);
        assertThatThrownBy(() -> service.getProfileByUserId(404L)).hasMessage("用户不存在");
    }

    @Test
    void coversHealthProfileInsertUpdateDefaultsAndJsonFallback() {
        when(healthProfileMapper.selectOne(any())).thenReturn(null);
        assertThat(service.getHealthProfile().bmi()).isEqualByComparingTo("0");

        HealthProfile stored = profile(1L, "[\"高血压\"]");
        when(healthProfileMapper.selectOne(any())).thenReturn(null, stored);
        var inserted = service.updateHealthProfile(new HealthProfileUpdateDTO(
                new BigDecimal("170"), new BigDecimal("68"), List.of("高血压"),
                " 花粉 ", " 既往史 ", " 手环 "
        ));
        assertThat(inserted.bmi()).isEqualByComparingTo("23.5");
        assertThat(inserted.chronicDiseases()).containsExactly("高血压");
        verify(healthProfileMapper).insert(any(HealthProfile.class));

        HealthProfile existing = profile(2L, "not-json");
        when(healthProfileMapper.selectOne(any())).thenReturn(existing, existing);
        var updated = service.updateHealthProfile(new HealthProfileUpdateDTO(
                null, null, null, " ", null, null
        ));
        assertThat(updated.chronicDiseases()).isEmpty();
        verify(healthProfileMapper).update(any());
    }

    @Test
    void coversHealthGoalInsertUpdateValidationAndProgress() {
        when(healthGoalMapper.selectOne(any())).thenReturn(null);
        assertThat(service.getHealthGoal().stepsTarget()).isEqualTo("8000");

        HealthGoal insertedGoal = goal(1L, "10000", "8", "130/85");
        when(healthGoalMapper.selectOne(any())).thenReturn(null, insertedGoal);
        var inserted = service.updateHealthGoal(new HealthGoalUpdateDTO(
                "10000", " 步数 ", "8.0", " 睡眠 ", "130／85", " 血压 "
        ));
        assertThat(inserted.sleepTarget()).isEqualTo("8");
        verify(healthGoalMapper).insert(any(HealthGoal.class));

        HealthGoal existing = goal(2L, "8000", "7.5", "140/90");
        when(healthGoalMapper.selectOne(any())).thenReturn(existing, existing);
        service.updateHealthGoal(new HealthGoalUpdateDTO("9000", null, "7.5", null, "140/90", null));
        verify(healthGoalMapper).update(any());

        List<HealthGoalUpdateDTO> invalid = List.of(
                new HealthGoalUpdateDTO(null, null, "7", null, "140/90", null),
                new HealthGoalUpdateDTO("abc", null, "7", null, "140/90", null),
                new HealthGoalUpdateDTO("1000000", null, "7", null, "140/90", null),
                new HealthGoalUpdateDTO("0", null, "7", null, "140/90", null),
                new HealthGoalUpdateDTO("100", null, null, null, "140/90", null),
                new HealthGoalUpdateDTO("100", null, "abc", null, "140/90", null),
                new HealthGoalUpdateDTO("100", null, "25", null, "140/90", null),
                new HealthGoalUpdateDTO("100", null, "7", null, null, null),
                new HealthGoalUpdateDTO("100", null, "7", null, "bad", null),
                new HealthGoalUpdateDTO("100", null, "7", null, "80/90", null)
        );
        for (HealthGoalUpdateDTO dto : invalid) {
            assertThatThrownBy(() -> service.updateHealthGoal(dto)).isInstanceOf(IllegalArgumentException.class);
        }

        when(healthGoalMapper.selectOne(any())).thenReturn(goal(3L, "10000", "8", "130/85"));
        HealthRecord steps = metric("steps", "8500", null, null);
        HealthRecord sleep = metric("sleep_hours", null, null, null);
        sleep.setValue1(new BigDecimal("8"));
        HealthRecord pressure = metric("blood_pressure", null, 125, 80);
        when(healthRecordMapper.selectOne(any())).thenReturn(steps, sleep, pressure);
        HealthGoalProgressVO progress = service.getHealthGoalProgress();
        assertThat(progress.steps().status()).isEqualTo("接近达标");
        assertThat(progress.sleep().status()).isEqualTo("已达标");
        assertThat(progress.bloodPressure().status()).isEqualTo("已达标");

        when(healthRecordMapper.selectOne(any())).thenReturn(null, null, null);
        assertThat(service.getHealthGoalProgress().bloodPressure().status()).isEqualTo("待记录");
    }

    @Test
    void coversSettingsInsertUpdateAndFontScaleBounds() {
        when(userSettingMapper.selectOne(any())).thenReturn(null);
        assertThat(service.getSettings().fontScale()).isEqualByComparingTo("1.00");

        UserSetting low = setting(1L, new BigDecimal("0.85"));
        when(userSettingMapper.selectOne(any())).thenReturn(null, low);
        var inserted = service.updateSettings(new UserSettingUpdateDTO(
                new BigDecimal("0.5"), null, true, true
        ));
        assertThat(inserted.fontScale()).isEqualByComparingTo("0.85");
        verify(userSettingMapper).insert(any(UserSetting.class));

        UserSetting high = setting(2L, new BigDecimal("1.30"));
        when(userSettingMapper.selectOne(any())).thenReturn(high, high);
        service.updateSettings(new UserSettingUpdateDTO(new BigDecimal("2"), false, null, null));
        verify(userSettingMapper).update(any());

        assertThat((BigDecimal) ReflectionTestUtils.invokeMethod(
                service, "clampFontScale", new BigDecimal("1.126")))
                .isEqualTo(new BigDecimal("1.13"));
    }

    @Test
    void coversPrivateParsingAndFormattingFallbackBranches() {
        assertThat((BigDecimal) ReflectionTestUtils.invokeMethod(service, "parseDecimal", null, BigDecimal.TEN))
                .isEqualByComparingTo("10");
        assertThat((BigDecimal) ReflectionTestUtils.invokeMethod(service, "parseDecimal", "no-number", BigDecimal.TEN))
                .isEqualByComparingTo("10");
        assertThat((BigDecimal) ReflectionTestUtils.invokeMethod(service, "parseDecimal", "目标 1,234", BigDecimal.ZERO))
                .isEqualByComparingTo("1234");

        assertThat((int[]) ReflectionTestUtils.invokeMethod(
                service, "parseBloodPressureTarget", (Object) null))
                .containsExactly(140, 90);
        assertThat((int[]) ReflectionTestUtils.invokeMethod(service, "parseBloodPressureTarget", "invalid"))
                .containsExactly(140, 90);
        assertThat((int[]) ReflectionTestUtils.invokeMethod(service, "parseBloodPressureTarget", "130/85"))
                .containsExactly(130, 85);

        HealthRecord pressure = metric("blood_pressure", null, 120, 80);
        assertThat((BigDecimal) ReflectionTestUtils.invokeMethod(service, "metricValue", pressure))
                .isEqualByComparingTo("120");
        HealthRecord empty = metric("steps", null, null, null);
        assertThat((BigDecimal) ReflectionTestUtils.invokeMethod(service, "metricValue", empty))
                .isEqualByComparingTo("0");

        assertThat((String) ReflectionTestUtils.invokeMethod(service, "blankToNull", "  x  ")).isEqualTo("x");
        assertThat((String) ReflectionTestUtils.invokeMethod(service, "blankToNull", " ")).isNull();
    }

    private User user(Long id, String username) {
        User user = new User();
        user.setId(id);
        user.setUsername(username);
        user.setNickname("昵称");
        user.setPasswordHash("bcrypt");
        return user;
    }

    private HealthProfile profile(Long id, String diseases) {
        HealthProfile profile = new HealthProfile();
        profile.setId(id);
        profile.setUserId(42L);
        profile.setHeight(new BigDecimal("170"));
        profile.setWeight(new BigDecimal("68"));
        profile.setChronicDiseases(diseases);
        return profile;
    }

    private HealthGoal goal(Long id, String steps, String sleep, String pressure) {
        HealthGoal goal = new HealthGoal();
        goal.setId(id);
        goal.setUserId(42L);
        goal.setStepsTarget(steps);
        goal.setSleepTarget(sleep);
        goal.setBloodPressureTarget(pressure);
        return goal;
    }

    private UserSetting setting(Long id, BigDecimal scale) {
        UserSetting setting = new UserSetting();
        setting.setId(id);
        setting.setUserId(42L);
        setting.setFontScale(scale);
        setting.setNotificationEnabled(true);
        setting.setLargeTouchTarget(false);
        setting.setSimpleMode(false);
        return setting;
    }

    private HealthRecord metric(String type, String value, Integer systolic, Integer diastolic) {
        HealthRecord record = new HealthRecord();
        record.setId(1L);
        record.setUserId(42L);
        record.setType(type);
        record.setValue(value == null ? null : new BigDecimal(value));
        record.setSystolic(systolic);
        record.setDiastolic(diastolic);
        return record;
    }
}

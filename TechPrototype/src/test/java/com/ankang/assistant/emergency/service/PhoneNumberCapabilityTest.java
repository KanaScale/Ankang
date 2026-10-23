package com.ankang.assistant.emergency.service;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class PhoneNumberCapabilityTest {

    @Test
    void recognizesChineseMobileAsSmsCapable() {
        PhoneNumberCapability.Result result = PhoneNumberCapability.resolve("13800008888");
        assertThat(result.e164()).isEqualTo("+8613800008888");
        assertThat(result.type()).isEqualTo("mobile");
        assertThat(result.smsCapable()).isTrue();
    }

    @Test
    void rejectsLandlineInternationalAndInvalidNumbers() {
        assertThatThrownBy(() -> PhoneNumberCapability.resolve(null))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> PhoneNumberCapability.resolve("010-88886666"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("请输入正确的大陆手机号");
        assertThatThrownBy(() -> PhoneNumberCapability.resolve("+14155552671"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("请输入正确的大陆手机号");
        assertThatThrownBy(() -> PhoneNumberCapability.resolve("12345678"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("请输入正确的大陆手机号");
    }

    @Test
    void legacyResolutionKeepsValidCapabilityAndSafelyDowngradesInvalidInput() {
        PhoneNumberCapability.Result valid =
                PhoneNumberCapability.resolveLegacy(" 13800008888 ");
        PhoneNumberCapability.Result invalid =
                PhoneNumberCapability.resolveLegacy("invalid");

        assertThat(valid.smsCapable()).isTrue();
        assertThat(valid.e164()).isEqualTo("+8613800008888");
        assertThat(invalid.smsCapable()).isFalse();
        assertThat(invalid.e164()).isNull();
        assertThat(invalid.type()).isEqualTo("unknown");
    }
}
